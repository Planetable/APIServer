import ENSKit
import Vapor
import NullCodable
import web3

struct Result: Codable {
    @NullCodable var address: String?
    @NullCodable var name: String?
    @NullCodable var displayName: String?
    @NullCodable var avatar: String?
    @NullCodable var contentHash: String?
    var juiceboxProjectID: String?
}

func routes(_ app: Application) throws {
    app.get { req async -> Response in
        let html = "ENS API maintained by <a href='https://planetable.xyz'>Planetable</a>"
        
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "text/html")
        return Response(status: .ok, headers: headers, body: .init(string: html))
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
        
        let enskit = ENSKit()
        
        // query is an address
        if normalized.hasPrefix("0x") && normalized.count == 42 {
            address = normalized

            // TODO: Get a checksummed address
            
            if let address = address, let resolvedName = await enskit.name(addr: address) {
                name = resolvedName
                displayName = name
                if let resolver = try? await enskit.resolver(name: resolvedName) {
                    if let avatar = try? await resolver.getAvatar(),
                       let avatarURL = try? await resolver.getAvatarImageURL(from: avatar) {
                        avatarURLString = avatarURL.absoluteString
                    }
                    if let contentHashURL = try? await resolver.contenthash() {
                        contentHash = contentHashURL.absoluteString
                    }
                    if let juiceboxProjectIDString = try? await resolver.text(key: "juicebox_project_id") {
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
                    if let resolver = try? await enskit.resolver(name: name) {
                        if let avatar = try? await resolver.getAvatar(),
                           let avatarURL = try? await resolver.getAvatarImageURL(from: avatar) {
                            avatarURLString = avatarURL.absoluteString
                        }
                        if let contentHashURL = try? await resolver.contenthash() {
                            contentHash = contentHashURL.absoluteString
                        }
                        if let juiceboxProjectIDString = try? await resolver.text(key: "juicebox_project_id") {
                            juiceboxProjectID = juiceboxProjectIDString
                        }
                    }
                }
            }
        }
        if displayName == nil,
           let address = address,
           address.count == 42 {
            displayName = String(address.prefix(5)) + "???" + String(address.suffix(4))
        }
        if avatarURLString != nil, let avatar = avatarURLString {
            if avatar.hasPrefix("ipfs://ipfs/") {
                avatarURLString = "https://ipfs.io/ipfs/" + avatar.replacingOccurrences(of: "ipfs://ipfs/", with: "")
            }
        }
        let result = Result(address: address, name: name, displayName: displayName, avatar: avatarURLString, contentHash: contentHash, juiceboxProjectID: juiceboxProjectID)
        var headers = HTTPHeaders()
        let json: String = {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let jsonData = try encoder.encode(result)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    headers.add(name: "CDN-Cache-Control", value: "public, stale-while-revalidate=8640000, max-age=600")
                    return jsonString
                }
            } catch {
            }
            return "{}"
        }()
        headers.add(name: .contentType, value: "application/json")
        return Response(status: .ok, headers: headers, body: .init(string: json))
    }
}
