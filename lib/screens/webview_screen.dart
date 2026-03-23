import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';

class WebViewScreen extends StatefulWidget {
  final String initialUrl;
  const WebViewScreen({super.key, required this.initialUrl});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isOffline = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _checkConnectivity();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('${AppConstants.appName}/1.0 Flutter Mobile App')
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() { _isLoading = true; }),
        onPageFinished: (_) => setState(() { _isLoading = false; }),
        onProgress: (p) => setState(() { _progress = p / 100; }),
        onNavigationRequest: (req) {
          final host = Uri.tryParse(req.url)?.host ?? '';
          final allowed = AppConstants.allowedDomains.any((d) => host.contains(d));
          return allowed ? NavigationDecision.navigate : NavigationDecision.prevent;
        },
      ))
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() { _isOffline = result == ConnectivityResult.none; });
    Connectivity().onConnectivityChanged.listen((r) {
      setState(() { _isOffline = r == ConnectivityResult.none; });
      if (r != ConnectivityResult.none) _controller.reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (await _controller.canGoBack()) {
          _controller.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              if (_isOffline)
                _OfflineView(onRetry: () {
                  setState(() { _isOffline = false; });
                  _controller.reload();
                })
              else
                WebViewWidget(controller: _controller),
              if (_isLoading && !_isOffline)
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.transparent,
                  color: AppTheme.primary,
                ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.small(
          onPressed: () => _controller.reload(),
          backgroundColor: AppTheme.primary,
          child: const Icon(Icons.refresh, color: Colors.white),
        ),
      ),
    );
  }
}

class _OfflineView extends StatelessWidget {
  final VoidCallback onRetry;
  const _OfflineView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No internet connection', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
