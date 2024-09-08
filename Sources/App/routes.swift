import ENSKit
import Foundation
import NullCodable
import Vapor
import web3

struct Result: Codable {
    @NullCodable var address: String?
    @NullCodable var name: String?
    @NullCodable var displayName: String?
    @NullCodable var avatar: String?
    @NullCodable var contentHash: String?
    var juiceboxProjectID: String?
}

enum CustomError: Error {
    case invalidURL
    case unexpectedResponseFormat
}

enum EthereumNetwork: String {
    case mainnet = "mainnet"
    case goerli = "goerli"
}

func getNamesFromSubgraph(address: String, network: EthereumNetwork = .mainnet) async throws -> [String] {
    let urlString = {
        switch network {
        case .mainnet:
            return "https://api.thegraph.com/subgraphs/name/ensdomains/ens"
        case .goerli:
            return "https://api.thegraph.com/subgraphs/name/ensdomains/ensgoerli"
        }
    }()
    guard let url = URL(string: urlString) else {
        throw CustomError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "content-type")
    request.addValue("https://app.ens.domains", forHTTPHeaderField: "origin")
    request.addValue("https://app.ens.domains/", forHTTPHeaderField: "referer")

    // TODO: A new query is needed for Goerli and the new NameWrapper contract
    let query = """
        query getNamesFromSubgraph($address: String!) {
            domains(first: 1000, where: {owner: $address}) {
                name
            }
        }
        """

    let requestBody: [String: Any] = [
        "operationName": "getNamesFromSubgraph",
        "variables": ["address": address],
        "query": query,
    ]

    request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody, options: [])

    let (data, _) = try await URLSession.shared.data(for: request)
    guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
        let domainsData = json["data"] as? [String: Any],
        let domains = domainsData["domains"] as? [[String: String]]
    else {
        throw CustomError.unexpectedResponseFormat
    }

    let domainNames = domains.compactMap { $0["name"] }
    return domainNames
}

func routes(_ app: Application) throws {
    app.get { req async -> Response in
        let html = "ENS API maintained by <a href='https://planetable.xyz'>Planetable</a>"

        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "text/html")
        return Response(status: .ok, headers: headers, body: .init(string: html))
    }

    app.get("ens", "list", ":addr") { req async -> Response in
        var output: String = "[]"
        var headers = HTTPHeaders()

        var addr: String = req.parameters.get("addr")!

        // If addr is an ENS name, resolve it to an address
        if addr.hasSuffix(".eth") {
            let enskit = ENSKit()
            if let resolver = try? await enskit.resolver(name: addr) {
                if let resolvedAddress = try? await resolver.addr() {
                    addr = "0x" + resolvedAddress.lowercased()
                }
            }
        }

        do {
            let domainNames = try await getNamesFromSubgraph(address: addr.lowercased())
            print("Domain names: \(domainNames)")
            if let data = try? JSONEncoder().encode(domainNames),
                let str = String(data: data, encoding: .utf8)
            {
                output = str
            }
        }
        catch {
            print("Error: \(error.localizedDescription)")
        }

        headers.add(name: .contentType, value: "application/json")
        return Response(status: .ok, headers: headers, body: .init(string: output))
    }

    app.get("ens", "list-goerli", ":addr") { req async -> Response in
        var output: String = "[]"
        var headers = HTTPHeaders()

        var addr: String = req.parameters.get("addr")!

        // If addr is an ENS name, resolve it to an address
        if addr.hasSuffix(".eth") {
            let enskit = ENSKit()
            if let resolver = try? await enskit.resolver(name: addr) {
                if let resolvedAddress = try? await resolver.addr() {
                    addr = "0x" + resolvedAddress.lowercased()
                }
            }
        }

        do {
            let domainNames = try await getNamesFromSubgraph(address: addr.lowercased(), network: .goerli)
            print("Domain names: \(domainNames)")
            if let data = try? JSONEncoder().encode(domainNames),
                let str = String(data: data, encoding: .utf8)
            {
                output = str
            }
        }
        catch {
            print("Error: \(error.localizedDescription)")
        }

        headers.add(name: .contentType, value: "application/json")
        return Response(status: .ok, headers: headers, body: .init(string: output))
    }

    app.get("ens", "resolve", ":query") { req async -> Response in
        let query = req.parameters.get("query")!
        let normalized = query.lowercased()

        var address: String? = nil
        var name: String? = nil
        var displayName: String? = nil
        var avatarURLString: String? = nil
        var contentHash: String? = nil
        var juiceboxProjectID: String? = nil

        let enskit = ENSKit(jsonrpcClient: EthereumAPI.Flashbots)

        // query is an address
        if normalized.hasPrefix("0x") && normalized.count == 42 {
            address = normalized

            // TODO: Get a checksummed address

            if let address = address, let resolvedName = await enskit.name(addr: address) {
                name = resolvedName
                displayName = name
                if let resolver = try? await enskit.resolver(name: resolvedName) {
                    if let contentHashURL = try? await resolver.contenthash() {
                        contentHash = contentHashURL.absoluteString
                    }
                    if let juiceboxProjectIDString = try? await resolver.text(
                        key: "juicebox_project_id"
                    ) {
                        juiceboxProjectID = juiceboxProjectIDString
                    }
                }
            }
        }
        // query is a name
        if normalized.hasSuffix(".eth") {
            name = normalized
            if let name = name, let resolver = try? await enskit.resolver(name: name) {
                if let resolvedAddress = try? await resolver.addr() {
                    address = "0x" + resolvedAddress.lowercased()
                    displayName = name
                }
                if let contentHashURL = try? await resolver.contenthash() {
                    contentHash = contentHashURL.absoluteString
                }
                if let juiceboxProjectIDString = try? await resolver.text(
                    key: "juicebox_project_id"
                ) {
                    juiceboxProjectID = juiceboxProjectIDString
                }
            }
        }
        if displayName == nil,
            let address = address,
            address.count == 42
        {
            displayName = String(address.prefix(5)) + "…" + String(address.suffix(4))
        } else {
            if let name = name {
                avatarURLString = "https://metadata.ens.domains/mainnet/avatar/" + name
            }
        }
        let result = Result(
            address: address,
            name: name,
            displayName: displayName,
            avatar: avatarURLString,
            contentHash: contentHash,
            juiceboxProjectID: juiceboxProjectID
        )
        var headers = HTTPHeaders()
        let json: String = {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                let jsonData = try encoder.encode(result)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    headers.add(
                        name: "CDN-Cache-Control",
                        value: "public, stale-while-revalidate=8640000, max-age=600"
                    )
                    return jsonString
                }
            }
            catch {
            }
            return "{}"
        }()
        headers.add(name: .contentType, value: "application/json")
        return Response(status: .ok, headers: headers, body: .init(string: json))
    }
}
