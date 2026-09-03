import Flutter
import SpotifyiOS

class RemoteManager: NSObject {
    static let shared = RemoteManager()

    var appRemote: SPTAppRemote?
    // The pair the live `appRemote` was built with. A connect for the same pair
    // reuses it (keeping its token and its handler bindings); a different pair
    // rebuilds.
    private(set) var appRemoteClientID: String?
    private(set) var appRemoteRedirectURL: URL?

    // One delegate for the manager's lifetime: a reconnect, or a rebuilt remote,
    // keeps feeding the same Dart sinks instead of orphaning them.
    let playerDelegate = PlayerDelegate()

    var connectionStatusHandler: ConnectionStatusHandler?
    var playerStateHandler: PlayerStateHandler?
    var playerContextHandler: PlayerContextHandler?
    var capabilitiesHandler: CapabilitiesHandler?
    var userStatusHandler: UserStatusHandler?

    static var playerStateChannel: FlutterEventChannel?
    static var playerContextChannel: FlutterEventChannel?
    static var capabilitiesChannel: FlutterEventChannel?
    static var userStatusChannel: FlutterEventChannel?
    static var connectionStatusChannel: FlutterEventChannel?

    override init() {
        super.init()
    }

    /// The remote to connect with: the live one when it was built for this
    /// client + redirect, otherwise a fresh one (the stale one is disconnected).
    func appRemote(clientID: String, redirectURL: URL) -> SPTAppRemote {
        if let existing = appRemote,
           RemoteManager.canReuse(clientID: appRemoteClientID, redirectURL: appRemoteRedirectURL,
                                  forClientID: clientID, redirectURL: redirectURL) {
            return existing
        }
        if let stale = appRemote, stale.isConnected {
            stale.disconnect()
        }
        let configuration = SPTConfiguration(clientID: clientID, redirectURL: redirectURL)
        let fresh = SPTAppRemote(configuration: configuration, logLevel: .none)
        appRemote = fresh
        appRemoteClientID = clientID
        appRemoteRedirectURL = redirectURL
        return fresh
    }

    static func canReuse(clientID: String?, redirectURL: URL?,
                         forClientID requestedClientID: String, redirectURL requestedRedirectURL: URL) -> Bool {
        return clientID == requestedClientID && redirectURL == requestedRedirectURL
    }
}
