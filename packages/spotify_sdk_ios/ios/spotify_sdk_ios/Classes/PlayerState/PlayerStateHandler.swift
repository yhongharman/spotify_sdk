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

    /// Arms the native subscription on the live remote. Runs when a Dart listener
    /// attaches and again on every established connection: `playerAPI` is nil
    /// until connected, and a reconnect on the reused remote needs a fresh
    /// subscription or the stream stays silent.
    func subscribe() {
        guard eventSink != nil, let playerAPI = remoteManager.appRemote?.playerAPI else { return }
        playerAPI.delegate = remoteManager.playerDelegate
        playerAPI.subscribe { (_, error) in
            if let error = error {
                print("Failed to subscribe to player state: \(error.localizedDescription)")
            }
        }
    }
}
