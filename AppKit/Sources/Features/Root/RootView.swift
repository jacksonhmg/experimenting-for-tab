import Combine
import ComposableArchitecture
import Inject
import SwiftUI
import UserNotifications


struct NotificationDetailView: View {
    let notificationText: String

    var body: some View {
        Text(notificationText)
            .padding()
    }
}

// MARK: - RootView
struct RootView: View {
  private let notificationDelegate = UNUserNotificationCenterDelegateAdaptor()
  @State private var showNotificationDetail: Bool = false


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

  // State variables
  @State private var buttonText = "Test Notification Detail"

  var body: some View {
    
      NavigationView {
        VStack {
          Button(buttonText) {
              showNotificationDetail.toggle()
          }
          
          ZStack {
              TabBarContainerView(
                  selectedIndex: viewStore.binding(get: \.rawValue, send: Root.Action.selectTab),
                  screen1: RecordingListScreenView(store: store.scope(state: \.recordingListScreen, action: Root.Action.recordingListScreen)),
                  screen2: RecordScreenView(store: store.scope(state: \.recordScreen, action: Root.Action.recordScreen)),
                  screen3: SettingsScreenView(store: store.scope(state: \.settingsScreen, action: Root.Action.settingsScreen))
              )
              .accentColor(.white)
              .onAppear(perform: requestNotificationPermission)
              .task { viewStore.send(.task) }
              .enableInjection()
              
              .sheet(isPresented: $showNotificationDetail) {
                NotificationDetailView(notificationText: buttonText)
              }
          }
        }
      }
      .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowNotificationDetail"))) { notification in
          print("Received the notification in the view!")
          if let body = notification.userInfo?["body"] as? String {
              buttonText = body
          }
      }
      
  }




}

class UNUserNotificationCenterDelegateAdaptor: NSObject, UNUserNotificationCenterDelegate {
    
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
      completionHandler([.banner, .sound, .badge])
  }

    
  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
      
      // Accessing the notification content
      let content = response.notification.request.content
      
      // Extracting the title, subtitle, and body of the notification
      let title = content.title
      let subtitle = content.subtitle
      let body = content.body
      
      print("Title: \(title), Subtitle: \(subtitle), Body: \(body)")
    
      print("Tapped the notification!")
      
      // Post a custom notification to indicate that the notification was tapped
    NotificationCenter.default.post(name: Notification.Name("ShowNotificationDetail"), object: nil, userInfo: ["body": body])

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
