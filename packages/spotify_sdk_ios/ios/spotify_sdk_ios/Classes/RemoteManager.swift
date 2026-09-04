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
    // Set when the live remote's last connection attempt failed. A remote that
    // reported a failure is not reused: the next connect rebuilds, which is how
    // upstream recovered a wedged remote before reuse existed.
    private(set) var lastConnectionAttemptFailed = false

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

    /// The remote to connect with. Reused only when `reuse` is set, it was built
    /// for this client + redirect, and its last attempt did not fail; otherwise
    /// a fresh one (the stale one is disconnected). Token connects pass `reuse`;
    /// the authorize path never does, so a re-authorize always starts clean and
    /// doubles as the manual reset for a remote that wedged without reporting.
    func appRemote(clientID: String, redirectURL: URL, reuse: Bool) -> SPTAppRemote {
        if reuse, let existing = appRemote,
           RemoteManager.canReuse(clientID: appRemoteClientID, redirectURL: appRemoteRedirectURL,
                                  lastAttemptFailed: lastConnectionAttemptFailed,
                                  forClientID: clientID, redirectURL: redirectURL) {
            return existing
        }
        if let stale = appRemote, stale.isConnected {
            stale.disconnect()
        }
        let configuration = SPTConfiguration(clientID: clientID, redirectURL: redirectURL)
        // Debug builds surface the SDK's own connection log on the device
        // console; it is the only view into why a connect is refused.
        #if DEBUG
        let logLevel: SPTAppRemoteLogLevel = .debug
        #else
        let logLevel: SPTAppRemoteLogLevel = .none
        #endif
        let fresh = SPTAppRemote(configuration: configuration, logLevel: logLevel)
        appRemote = fresh
        appRemoteClientID = clientID
        appRemoteRedirectURL = redirectURL
        lastConnectionAttemptFailed = false
        return fresh
    }

    /// The remote to issue a command on, or nil after answering `result` with
    /// the not-connected error. The SDK's `playerAPI`, `userAPI`, and `imageAPI`
    /// are nil on a disconnected remote, so an optional-chained call there
    /// silently never invokes its callback and the Dart future hangs forever.
    func connectedRemote(_ result: FlutterResult) -> SPTAppRemote? {
        guard let appRemote = appRemote, appRemote.isConnected else {
            result(SpotifyErrorMapper.notConnectedError())
            return nil
        }
        return appRemote
    }

    func markConnectionAttemptFailed() {
        lastConnectionAttemptFailed = true
    }

    func markConnectionEstablished() {
        lastConnectionAttemptFailed = false
    }

    static func canReuse(clientID: String?, redirectURL: URL?, lastAttemptFailed: Bool,
                         forClientID requestedClientID: String, redirectURL requestedRedirectURL: URL) -> Bool {
        return !lastAttemptFailed && clientID == requestedClientID && redirectURL == requestedRedirectURL
    }
}
