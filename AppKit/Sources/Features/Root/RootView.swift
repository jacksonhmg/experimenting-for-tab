import Combine
import ComposableArchitecture
import Inject
import SwiftUI
import UserNotifications


// MARK: - RootView




struct RootView: View {
  private let notificationDelegate = UNUserNotificationCenterDelegateAdaptor()

      func requestNotificationPermission() {
          let center = UNUserNotificationCenter.current()
          center.delegate = notificationDelegate  // Use the stored delegate
          center.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
              if granted {
                  print("Notification permissions granted.")
              } else {
                  print("Notification permissions denied.")
              }
          }
      }
  
  @ObserveInjection var inject

  let store: StoreOf<Root>

  @ObservedObject var viewStore: ViewStore<Root.Tab, Root.Action>

  @Namespace var animation

  init(store: StoreOf<Root>) {
    self.store = store
    viewStore = ViewStore(store) { $0.selectedTab }
  }

  var body: some View {
      TabBarContainerView(
        selectedIndex: viewStore.binding(get: \.rawValue, send: Root.Action.selectTab),
        screen1: RecordingListScreenView(store: store.scope(state: \.recordingListScreen, action: Root.Action.recordingListScreen)),
        screen2: RecordScreenView(store: store.scope(state: \.recordScreen, action: Root.Action.recordScreen)),
        screen3: SettingsScreenView(store: store.scope(state: \.settingsScreen, action: Root.Action.settingsScreen))
      )
      .accentColor(.white)
      .onAppear(perform: requestNotificationPermission)  // Add this line
      .task { viewStore.send(.task) }
      .enableInjection()
  }

}

class UNUserNotificationCenterDelegateAdaptor: NSObject, UNUserNotificationCenterDelegate {
    
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
      completionHandler([.banner, .sound, .badge])
  }

    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle the tap action here, you can use NotificationCenter or other patterns
        // to communicate with the rest of your app or simply print something
        print("Notification tapped!")
        completionHandler()
    }
}


// MARK: - Root_Previews

struct Root_Previews: PreviewProvider {
  struct ContentView: View {
    var body: some View {
      RootView(
        store: Store(
          initialState: Root.State(),
          reducer: { Root() }
        )
      )
    }
  }

  static var previews: some View {
    ContentView()
  }
}
