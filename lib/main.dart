import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );
  print('User granted permission: ${settings.authorizationStatus}');
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
    }
  });
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'خرابيط',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: WebViewExample(),
    );
  }
}

class WebViewExample extends StatefulWidget {
  @override
  WebViewExampleState createState() => WebViewExampleState();
}

class WebViewExampleState extends State<WebViewExample> {
  late WebViewController controller;
  bool isLoading = true;

  Future<void> _injectJavascript(WebViewController controller) async {
    await controller.evaluateJavascript(
        "window.addEventListener('load', function() { Flutter.postMessage('PageLoaded'); });");
  }

// CHANGE 1: Update method to handle background and terminated app cases
  void _onNotificationTap(RemoteMessage? message) {
    if (message != null && message.data.containsKey('targetUrl')) {
      String targetUrl = message.data['targetUrl'];
      controller.loadUrl(targetUrl);
    }
  }

  @override
  void initState() {
    super.initState();
// CHANGE 2: Update the listener for FirebaseMessaging.onMessageOpenedApp
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification clicked with message: ${message.data}');
      _onNotificationTap(message);
    });

// CHANGE 3: Add getInitialMessage to handle terminated app case
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      print('App opened with initial message: ${message?.data}');
      _onNotificationTap(message);
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (await controller.canGoBack()) {
          controller.goBack();
          return false;
        } else {
          return true;
        }
      },
      child: SafeArea(
        child: Scaffold(
          body: Stack(
            children: [
              WebView(
                initialUrl: 'https://krabet.com',
                javascriptMode: JavascriptMode.unrestricted,
                onWebViewCreated: (WebViewController webViewcontroller) {
                  controller = webViewcontroller;
                },
                onWebResourceError: (error) {
                  setState(() {
                    isLoading = false;
                  });
                },
                navigationDelegate: (NavigationRequest request) {
                  setState(() {
                    isLoading = true;
                  });
                  return NavigationDecision.navigate;
                },
                onPageFinished: (url) async {
                  await _injectJavascript(controller);
                },
                javascriptChannels: {
                  JavascriptChannel(
                      name: 'Flutter',
                      onMessageReceived: (JavascriptMessage message) {
                        if (message.message == 'PageLoaded') {
                          setState(() {
                            isLoading = false;
                          });
                        }
                      }),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
