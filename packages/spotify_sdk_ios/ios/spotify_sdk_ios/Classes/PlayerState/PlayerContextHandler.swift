import Flutter
import SpotifyiOS

class PlayerContextHandler: StatusHandler {
    private unowned let remoteManager: RemoteManager

    init(remoteManager: RemoteManager) {
        self.remoteManager = remoteManager
        super.init()
    }

    override func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        _ = super.onListen(withArguments: arguments, eventSink: events)
        remoteManager.playerDelegate.playerContextSink = events
        return nil
    }

    override func onCancel(withArguments arguments: Any?) -> FlutterError? {
        remoteManager.playerDelegate.playerContextSink = nil
        return super.onCancel(withArguments: arguments)
    }
}
