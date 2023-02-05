import ENSKit
import Vapor

struct Result: Codable {
    let address: String?
    let name: String?
    let displayName: String?
    let avatar: String?
    let contentHash: String?
}

func routes(_ app: Application) throws {
    app.get { req async in
        "ENS API maintained by <a href='https://planetable.xyz'>Planetable</a>"
    }

    app.get("resolve", ":query") { req async -> String in
        let query = req.parameters.get("query")!
        let normalized = query.lowercased()
        
        var address: String? = nil
        var name: String? = nil
        var displayName: String? = nil
        var avatarURLString: String? = nil
        var contentHash: String? = nil
        
        let enskit = ENSKit()
        
        // query is an address
        if normalized.hasPrefix("0x") && normalized.count == 42 {
            address = normalized
            
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
                }
            }
        }
        // query is a name
        if normalized.hasSuffix(".eth") {
            name = normalized
            if let name = name, let resolver = try? await enskit.resolver(name: name) {
                if let resolvedAddress = try? await resolver.addr() {
                    address = "0x" + resolvedAddress
                    displayName = name
                    if let resolver = try? await enskit.resolver(name: name) {
                        if let avatar = try? await resolver.getAvatar(),
                           let avatarURL = try? await resolver.getAvatarImageURL(from: avatar) {
                            avatarURLString = avatarURL.absoluteString
                        }
                        if let contentHashURL = try? await resolver.contenthash() {
                            contentHash = contentHashURL.absoluteString
                        }
                    }
                }
            }
        }
        let result = Result(address: address, name: name, displayName: displayName, avatar: avatarURLString, contentHash: contentHash)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(result)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
        } catch {
        }
        return ""
    }
}
