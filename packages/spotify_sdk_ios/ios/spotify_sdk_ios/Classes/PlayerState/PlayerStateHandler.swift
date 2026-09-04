import Flutter
import SpotifyiOS

class PlayerStateHandler: StatusHandler {
    private unowned let remoteManager: RemoteManager

    init(remoteManager: RemoteManager) {
        self.remoteManager = remoteManager
        super.init()
    }

    override func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        _ = super.onListen(withArguments: arguments, eventSink: events)
        remoteManager.playerDelegate.playerStateSink = events
        subscribe()
        return nil
    }

    override func onCancel(withArguments arguments: Any?) -> FlutterError? {
        remoteManager.playerDelegate.playerStateSink = nil
        return super.onCancel(withArguments: arguments)
    }

    /// The remote whose connection currently carries a subscription. Both the
    /// Dart listener attaching and every established connection call
    /// [subscribe]; without this, a rebuilt remote gets two SDK subscriptions
    /// and every player-state event arrives twice.
    private weak var subscribedRemote: SPTAppRemote?

    /// Arms the native subscription on the live remote once per connection.
    /// `playerAPI` is nil until connected, and a reconnect needs a fresh
    /// subscription or the stream stays silent, so [resetSubscription] runs on
    /// every disconnect.
    func subscribe() {
        guard eventSink != nil, let appRemote = remoteManager.appRemote, let playerAPI = appRemote.playerAPI else { return }
        if subscribedRemote === appRemote {
            return
        }
        subscribedRemote = appRemote
        playerAPI.delegate = remoteManager.playerDelegate
        playerAPI.subscribe { (_, error) in
            if let error = error {
                print("Failed to subscribe to player state: \(error.localizedDescription)")
            }
        }
    }

    func resetSubscription() {
        subscribedRemote = nil
    }
}
