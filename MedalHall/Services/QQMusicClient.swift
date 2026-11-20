import Foundation

/// QQ 音乐接口客户端。等价于原 Node 项目的 server.js：
/// `/api/parse`、`/api/members`、`/api/module`、`/api/medal`、`/api/skins` 的能力都在这里。
final class QQMusicClient {
    static let shared = QQMusicClient()

    private static let apiURL = "https://u6.y.qq.com/cgi-bin/musics.fcg"
    private static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 25
            configuration.timeoutIntervalForResource = 45
            configuration.httpAdditionalHeaders = ["Accept-Language": "zh-CN,zh;q=0.9"]
            self.session = URLSession(configuration: configuration)
        }
    }

    // MARK: - 底层请求

    private func baseHeaders(contentType: String?) -> [String: String] {
        var headers = [
            "User-Agent": Self.userAgent,
            "Referer": "https://y.qq.com/",
            "Origin": "https://y.qq.com",
            "Accept": "application/json, text/plain, */*"
        ]
        if let contentType {
            headers["Content-Type"] = contentType
        }
        return headers
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw QQMusicError.network("没有收到响应")
            }
            guard (200..<300).contains(http.statusCode) else {
                throw QQMusicError.network("HTTP \(http.statusCode)")
            }
            return data
        } catch let error as QQMusicError {
            throw error
        } catch {
            throw QQMusicError.network(error.localizedDescription)
        }
    }

    /// 抓取页面 HTML。
    func page(url: String) async throws -> String {
        guard let target = URL(string: url) else {
            throw QQMusicError.invalidURL(url)
        }
        var request = URLRequest(url: target)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        for (key, value) in baseHeaders(contentType: "text/html,application/xhtml+xml") {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let data = try await perform(request)
        return String(decoding: data, as: UTF8.self)
    }

    /// 调用 CGI 接口（原 server.js 的 callCGI）。
    func cgi(
        _ webcgikey: String,
        module: String,
        method: String,
        param: [String: Any]
    ) async throws -> [String: Any] {
        let request0: [String: Any] = ["module": module, "method": method, "param": param]
        let payload: [String: Any] = ["comm": [String: Any](), "req_0": request0]

        let body: Data
        do {
            body = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            throw QQMusicError.decoding("请求参数无法序列化")
        }

        let sign = QQSigner.sign(body)
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        guard var components = URLComponents(string: Self.apiURL) else {
            throw QQMusicError.invalidURL(Self.apiURL)
        }
        components.queryItems = [
            URLQueryItem(name: "_webcgikey", value: webcgikey),
            URLQueryItem(name: "_", value: String(timestamp)),
            URLQueryItem(name: "sign", value: sign)
        ]
        guard let url = components.url else {
            throw QQMusicError.invalidURL(Self.apiURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        for (key, value) in baseHeaders(contentType: "application/json;charset=UTF-8") {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let data = try await perform(request)
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw QQMusicError.decoding("接口返回的不是 JSON")
        }
        guard let json = object as? [String: Any] else {
            throw QQMusicError.decoding("接口返回的不是 JSON 对象")
        }
        return json
    }

    private func cgiResult(
        _ webcgikey: String,
        module: String,
        method: String,
        param: [String: Any]
    ) async throws -> [String: Any] {
        let response = try await cgi(webcgikey, module: module, method: method, param: param)
        return response.dict("req_0")
    }

    // MARK: - 家族

    func fetchFamily(rawURL: String) async throws -> Family {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw QQMusicError.invalidURL(trimmed)
        }

        var html = try await page(url: trimmed)
        var root = SSR.firstPageData(from: html) as? [String: Any]
        var familyId = QQMusicParsers.familyID(fromHTML: html)

        if familyId == nil, let root {
            let query = root.dict("query")
            let data = root.dict("data")
            let fromQuery = query.string("family_id")
            let fromData = data.string("MedalID")
            familyId = fromQuery.isEmpty ? (fromData.isEmpty ? nil : fromData) : fromQuery
        }
        if familyId == nil {
            familyId = QQMusicParsers.familyID(fromURL: trimmed)
        }
        guard let identifier = familyId, !identifier.isEmpty else {
            throw QQMusicError.decoding("无法提取 family_id")
        }

        var familyData = root?.dict("data") ?? [:]
        if familyData.string("Name").isEmpty {
            let encoded = identifier.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? identifier
            let fallbackURL = "https://i2.y.qq.com/?family_id=" + encoded
            html = try await page(url: fallbackURL)
            root = SSR.firstPageData(from: html) as? [String: Any]
            familyData = root?.dict("data") ?? [:]
            if familyData.isEmpty {
                familyData = root?.dict("req_0").dict("data") ?? [:]
            }
        }
        guard !familyData.string("Name").isEmpty else {
            throw QQMusicError.empty("未找到家族数据，请确认链接是否有效")
        }

        return QQMusicParsers.family(from: familyData, id: identifier, rawURL: trimmed)
    }

    // MARK: - 家族成员（/api/members）

    func fetchMembers(familyId: String) async throws -> [Member] {
        let cleaned = familyId.split(separator: "#").first.map(String.init) ?? familyId
        let medalId = cleaned.split(separator: "_").first.map(String.init) ?? cleaned

        let response = try await cgiResult(
            "GetRankTabDetail",
            module: "music.medalHall.MedalRankListSrv",
            method: "GetRankTabDetail",
            param: [
                "MedalID": medalId,
                "TabID": 5,
                "FirstPageSize": 20,
                "From": 2,
                "Target": cleaned
            ]
        )

        let code = response.int("code")
        guard code == 0 else {
            throw QQMusicError.server(response.nonEmpty("msg", fallback: "code=\(code)"))
        }

        let detail = response.dict("data").dict("Detail")
        let firstPage = detail.dictArray("FirstPageInfo")
        let itemList = detail.dictArray("ItemList")

        var members = firstPage.map { QQMusicParsers.member(from: $0, familyID: cleaned) }
        var seen = Set(firstPage.map { $0.string("ItemID") }.filter { !$0.isEmpty })

        var remaining: [[String: Any]] = []
        for item in itemList {
            let itemID = item.string("ItemID")
            guard !itemID.isEmpty, !seen.contains(itemID) else { continue }
            remaining.append(["ItemID": itemID, "Value": item["Value"] ?? ""])
            seen.insert(itemID)
        }

        if !remaining.isEmpty {
            let batch = try await cgiResult(
                "BatchGetRankItem",
                module: "music.medalHall.MedalRankListSrv",
                method: "BatchGetRankItem",
                param: ["MedalID": medalId, "TabID": 5, "Items": remaining]
            )
            let itemMap = batch.dict("data").dict("ItemMap")
            for key in itemMap.keys.sorted() {
                members.append(QQMusicParsers.member(from: JSONValue.dict(itemMap[key]), familyID: cleaned))
            }
        }

        return members
    }

    // MARK: - 勋章馆首页（/api/parse 普通页面）

    func fetchMedalPage(url: String) async throws -> MedalPageData {
        let html = try await page(url: url)
        let root = try SSR.root(fromHTML: html)
        let basics = QQMusicParsers.medalPageBasics(from: root)
        guard !basics.tabs.isEmpty else {
            throw QQMusicError.empty("该页面没有可用的勋章 Tab，可能需要在 App 内登录后再试")
        }

        var results: [MedalTabResult] = []
        for tab in basics.tabs {
            if tab.id == basics.currentTabID {
                results.append(MedalTabResult(tab: tab, success: true, errorMessage: nil, modules: basics.modules))
                continue
            }
            do {
                let response = try await cgiResult(
                    "GetHomepageTabDetail",
                    module: "music.medalHall.MedalHallHomepageSrv",
                    method: "GetHomepageTabDetail",
                    param: [
                        "EncUin": basics.encUin,
                        "TabID": tab.id,
                        "IsQueryTabDetail": true,
                        "SupportCardStyle": true
                    ]
                )
                let code = response.int("code")
                let modules = QQMusicParsers.parseModules(
                    response.dict("data").dict("TabInfo").dictArray("ModuleList")
                )
                results.append(MedalTabResult(
                    tab: tab,
                    success: code == 0,
                    errorMessage: code == 0 ? nil : "code=\(code)",
                    modules: modules
                ))
            } catch {
                results.append(MedalTabResult(
                    tab: tab,
                    success: false,
                    errorMessage: error.localizedDescription,
                    modules: []
                ))
            }
        }

        return MedalPageData(encUin: basics.encUin, desc: basics.desc, tabs: results)
    }

    // MARK: - 模块更多（/api/module）

    func fetchModule(
        encUin: String,
        moduleId: Int,
        lastPos: String = "",
        pageSize: Int = 21
    ) async throws -> (items: [MedalItem], lastPos: String, hasNext: Bool) {
        let response = try await cgiResult(
            "GetModuleDetail",
            module: "music.medalHall.MedalHallHomepageSrv",
            method: "GetModuleDetail",
            param: [
                "ModuleID": moduleId,
                "EncUin": encUin,
                "PageSize": pageSize,
                "LastPos": lastPos,
                "SupportCardStyle": true
            ]
        )
        let code = response.int("code")
        guard code == 0 else {
            throw QQMusicError.server(response.nonEmpty("msg", fallback: "code=\(code)"))
        }
        return QQMusicParsers.moduleItems(from: response.dict("data"))
    }

    // MARK: - 勋章详情（/api/medal）

    func fetchMedalDetail(encUin: String, medalId: String) async throws -> [String: Any] {
        let response = try await cgiResult(
            "GetMedalDetail",
            module: "music.medalHall.MedalHallHomepageSrv",
            method: "GetMedalDetail",
            param: ["MedalID": medalId, "EncUin": encUin]
        )
        let code = response.int("code")
        guard code == 0 else {
            throw QQMusicError.server(response.nonEmpty("msg", fallback: "code=\(code)"))
        }
        return response.dict("data")
    }

    // MARK: - 排行榜（/api/parse 排行榜页面）

    func fetchStarDetailRanking(url: String) async throws -> RankData {
        let params = QQMusicParsers.starDetailParams(from: url)
        guard !params.medalId.isEmpty else {
            throw QQMusicError.invalidURL(url)
        }

        var header: [String: Any] = [:]
        if let html = try? await page(url: url),
           let root = SSR.firstPageData(from: html) as? [String: Any] {
            header = root.dict("data")
        }

        let moduleResponse = try await cgiResult(
            "GetRankModule",
            module: "music.medalHall.MedalRankListSrv",
            method: "GetRankModule",
            param: [
                "MedalID": params.medalId,
                "FirstPageSize": 20,
                "From": 1,
                "Target": params.encUin
            ]
        )
        let module = QQMusicParsers.starDetailModule(from: moduleResponse)
        guard !module.tabs.isEmpty else {
            throw QQMusicError.empty("该勋章暂无排行榜 Tab")
        }

        var details: [RankTabDetail] = []
        for tab in module.tabs {
            if tab.type == module.firstTabID && !module.firstTabDetail.isEmpty {
                let enriched = await enrichRankDetail(
                    medalId: params.medalId,
                    tabType: tab.type,
                    detail: module.firstTabDetail
                )
                details.append(QQMusicParsers.rankTabDetail(tab: tab, detail: enriched))
                continue
            }
            do {
                let response = try await cgiResult(
                    "GetRankTabDetail",
                    module: "music.medalHall.MedalRankListSrv",
                    method: "GetRankTabDetail",
                    param: [
                        "MedalID": params.medalId,
                        "TabID": tab.type,
                        "FirstPageSize": 20,
                        "From": 1,
                        "Target": params.encUin
                    ]
                )
                var detail = response.dict("data").dict("Detail")
                if detail.isEmpty {
                    detail = response.dict("data")
                }
                let enriched = await enrichRankDetail(medalId: params.medalId, tabType: tab.type, detail: detail)
                let code = response.int("code")
                let ok = code == 0
                details.append(QQMusicParsers.rankTabDetail(
                    tab: tab,
                    detail: enriched,
                    success: ok,
                    errorMessage: ok ? nil : "code=\(code)"
                ))
            } catch {
                details.append(QQMusicParsers.rankTabDetail(
                    tab: tab,
                    detail: [:],
                    success: false,
                    errorMessage: error.localizedDescription
                ))
            }
        }

        return RankData(title: header.dict("Basic").string("Name"), tabs: details)
    }

    /// 把 ItemList 里缺的条目用 BatchGetRankItem 补齐，并按 ItemList 顺序生成 Position。
    private func enrichRankDetail(
        medalId: String,
        tabType: Int,
        detail: [String: Any]
    ) async -> [String: Any] {
        let itemList = detail.dictArray("ItemList")
        guard !itemList.isEmpty else { return detail }

        var itemMap: [String: Any] = [:]
        for item in detail.dictArray("FirstPageInfo") {
            let itemID = item.string("ItemID")
            if !itemID.isEmpty {
                itemMap[itemID] = item
            }
        }

        var missing: [[String: Any]] = []
        for item in itemList {
            let itemID = item.string("ItemID")
            if !itemID.isEmpty && itemMap[itemID] == nil {
                missing.append(item)
            }
        }

        var index = 0
        while index < missing.count {
            let end = min(index + 20, missing.count)
            let batch = Array(missing[index..<end])
            index = end
            do {
                let response = try await cgiResult(
                    "BatchGetRankItem",
                    module: "music.medalHall.MedalRankListSrv",
                    method: "BatchGetRankItem",
                    param: ["MedalID": medalId, "TabID": tabType, "Items": batch]
                )
                let map = response.dict("data").dict("ItemMap")
                for (key, value) in map {
                    itemMap[key] = value
                }
            } catch {
                continue
            }
        }

        var fullList: [[String: Any]] = []
        for (position, item) in itemList.enumerated() {
            let itemID = item.string("ItemID")
            var merged = item
            for (key, value) in JSONValue.dict(itemMap[itemID]) {
                merged[key] = value
            }
            merged["Position"] = position + 1
            fullList.append(merged)
        }

        var updated = detail
        updated["FirstPageInfo"] = fullList
        return updated
    }

    // MARK: - 勋章皮肤（/api/skins）

    func fetchSkinPage(
        medalId: String,
        encUin: String = "",
        cursor: String = "",
        pageSize: Int = 4
    ) async throws -> SkinPage {
        let response = try await cgiResult(
            "GetSkinShowList",
            module: "music.medalSkin.MedalSkinHomepageSrv",
            method: "GetSkinShowList",
            param: [
                "MedalID": medalId,
                "ShowPos": 1,
                "PageSize": pageSize,
                "Cursor": cursor,
                "EncUin": encUin
            ]
        )
        let code = response.int("code")
        let page = QQMusicParsers.skinPage(from: response, medalId: medalId)
        let hasPayload = page.total > 0 || !page.list.isEmpty || !page.medalName.isEmpty
        guard code == 0 || hasPayload else {
            throw QQMusicError.server(response.nonEmpty("msg", fallback: "code=\(code)"))
        }
        return page
    }

    /// 翻页拉全量皮肤（替代原 Web 版按 seq 逐个扫详情页的做法）。
    func fetchAllSkins(medalId: String, encUin: String = "") async throws -> (skins: [Skin], total: Int) {
        var all: [Skin] = []
        var seen = Set<String>()
        var cursor = ""
        var hasMore = true
        var pageGuard = 0
        var total = 0
        while hasMore && pageGuard < 30 {
            pageGuard += 1
            let page = try await fetchSkinPage(medalId: medalId, encUin: encUin, cursor: cursor, pageSize: 20)
            total = max(total, page.total)
            for skin in page.list where !seen.contains(skin.id) {
                seen.insert(skin.id)
                all.append(skin)
            }
            let next = page.nextCursor
            hasMore = page.hasMore && !next.isEmpty && next != cursor
            cursor = next
        }
        return (all, total > 0 ? total : all.count)
    }

    func fetchSkinTotal(medalId: String, encUin: String = "") async throws -> Int {
        let page = try await fetchSkinPage(medalId: medalId, encUin: encUin, pageSize: 4)
        return page.total
    }

    // MARK: - 链接

    /// 成员的勋章馆首页链接（对应原版 DEFAULT_MEDAL_URL_TEMPLATE）。
    static func medalURL(forItemID itemID: String) -> String {
        Persistence.defaultMedalURLTemplate.replacingOccurrences(of: "{ENC_UIN}", with: itemID)
    }
}
