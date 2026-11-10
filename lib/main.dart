import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// ====== PENGATURAN (ganti di sini kalau URL / nama berubah) ======
const String kSiteUrl = 'https://cfslinkbuster.vercel.app/';
const String kAppTitle = 'LINKBUSTER';
const Duration kMinSplash = Duration(milliseconds: 3200);
const Duration kMaxWait = Duration(seconds: 20);
const Color kSplashBg = Color(0xFFFEFEFE); // sama dengan background logo
const Color kSiteBg = Color(0xFFDCE8F7); // theme-color website
/// =================================================================

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Linkbuster',
      navigatorKey: navKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF1A1A1A)),
      home: const Root(),
    );
  }
}

/// Dialog modern pengganti alert()/confirm() bawaan WebView yang jadul.
Future<bool> showSiteDialog(String message, {required bool confirm}) async {
  final ctx = navKey.currentContext;
  if (ctx == null) return confirm ? false : true;
  final res = await showGeneralDialog<bool>(
    context: ctx,
    barrierDismissible: false,
    barrierLabel: 'dialog',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (c, a1, a2) => const SizedBox.shrink(),
    transitionBuilder: (c, anim, _, __) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 28),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF3FA),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 12)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'linkbuster',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1, color: Color(0xFF6B7A90)),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (confirm)
                          TextButton(
                            onPressed: () => Navigator.of(c).pop(false),
                            child: const Text('Batal', style: TextStyle(color: Color(0xFF4A5568), fontWeight: FontWeight.w700)),
                          ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1A1A1A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.of(c).pop(true),
                          child: Text(confirm ? 'Ya' : 'OK'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  return res ?? false;
}

enum Phase { splash, web, error }

class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  late final WebViewController _c;
  Phase _phase = Phase.splash;
  bool _ready = false; // website sudah selesai dimuat
  Completer<bool> _loaded = Completer<bool>();

  @override
  void initState() {
    super.initState();
    final siteHost = Uri.parse(kSiteUrl).host;

    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(kSiteBg)
      ..setOnJavaScriptAlertDialog((req) async {
        await showSiteDialog(req.message, confirm: false);
      })
      ..setOnJavaScriptConfirmDialog((req) => showSiteDialog(req.message, confirm: true))
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (r) {
          if (!r.isMainFrame) return NavigationDecision.navigate;
          final u = Uri.tryParse(r.url);
          if (u == null) return NavigationDecision.prevent;
          if (u.host == siteHost || u.scheme == 'about' || u.scheme == 'blob' || u.scheme == 'data') {
            return NavigationDecision.navigate;
          }
          // link keluar (link tujuan hasil bypass, dll) dibuka di browser HP
          launchUrl(u, mode: LaunchMode.externalApplication).catchError((_) => false);
          return NavigationDecision.prevent;
        },
        onPageFinished: (_) {
          if (!_loaded.isCompleted) _loaded.complete(true);
        },
        onWebResourceError: (e) {
          if (e.isForMainFrame != true) return;
          if (!_loaded.isCompleted) {
            _loaded.complete(false);
          } else if (mounted) {
            setState(() => _phase = Phase.error);
          }
        },
      ));

    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      _phase = Phase.splash;
      _ready = false;
    });
    if (_loaded.isCompleted) _loaded = Completer<bool>();
    _c.loadRequest(Uri.parse(kSiteUrl));

    final minWait = Future<void>.delayed(kMinSplash);
    final ok = await _loaded.future.timeout(kMaxWait, onTimeout: () => false);
    if (mounted) setState(() => _ready = ok);
    await minWait;
    await Future<void>.delayed(const Duration(milliseconds: 300)); // biar bar penuh dulu
    if (!mounted) return;
    setState(() => _phase = ok ? Phase.web : Phase.error);
  }

  Future<void> _onBack() async {
    if (_phase == Phase.web && await _c.canGoBack()) {
      await _c.goBack();
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    switch (_phase) {
      case Phase.splash:
        child = SplashView(key: const ValueKey('splash'), ready: _ready);
        break;
      case Phase.web:
        child = Scaffold(
          key: const ValueKey('web'),
          backgroundColor: kSiteBg,
          body: SafeArea(child: WebViewWidget(controller: _c)),
        );
        break;
      case Phase.error:
        child = ErrorView(key: const ValueKey('error'), onRetry: _boot);
        break;
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeOut,
        child: child,
      ),
    );
  }
}

class SplashView extends StatefulWidget {
  const SplashView({super.key, required this.ready});
  final bool ready;

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with SingleTickerProviderStateMixin {
  late final AnimationController _a =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward();
  late final Animation<double> _scale = Tween<double>(begin: 0.6, end: 1.0)
      .animate(CurvedAnimation(parent: _a, curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic)));
  late final Animation<double> _logoFade =
      CurvedAnimation(parent: _a, curve: const Interval(0.0, 0.55, curve: Curves.easeIn));
  late final Animation<double> _textFade =
      CurvedAnimation(parent: _a, curve: const Interval(0.5, 1.0, curve: Curves.easeOut));

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final logo = (w * 0.78).clamp(200.0, 420.0);
    return Scaffold(
      backgroundColor: kSplashBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _logoFade,
              child: ScaleTransition(
                scale: _scale,
                child: Image.asset('assets/cryfsall-logo.png', width: logo, height: logo, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 8),
            FadeTransition(
              opacity: _textFade,
              child: Column(
                children: [
                  const Text(
                    kAppTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Preparing your experience...',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B6B6B), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: 190,
                    height: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: widget.ready ? 1.0 : 0.9),
                        duration: widget.ready ? const Duration(milliseconds: 300) : const Duration(milliseconds: 3000),
                        curve: Curves.easeInOut,
                        builder: (_, v, __) => LinearProgressIndicator(
                          value: v,
                          backgroundColor: const Color(0xFFE4E4E4),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1A1A1A)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSplashBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/cryfsall-logo.png', width: 160, height: 160),
              const SizedBox(height: 12),
              const Text('Gagal memuat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                'Cek koneksi internet kamu, lalu coba lagi.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B6B6B)),
              ),
              const SizedBox(height: 22),
              FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
            ],
          ),
        ),
      ),
    );
  }
}
