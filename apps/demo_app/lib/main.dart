import 'package:flutter/material.dart';
import 'package:flutter_mate/flutter_mate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Flutter Mate for in-app AI agent usage
  await FlutterMate.initialize();

  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Mate Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _message = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Register controllers with FlutterMate for AI agent access
    FlutterMate.registerTextField('email', _emailController);
    FlutterMate.registerTextField('password', _passwordController);
  }

  @override
  void dispose() {
    // Unregister controllers
    FlutterMate.unregisterTextField('email');
    FlutterMate.unregisterTextField('password');
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    setState(() {
      _isLoading = true;
      _message = '';
    });

    await Future.delayed(const Duration(seconds: 1));

    final email = _emailController.text;
    final password = _passwordController.text;

    setState(() {
      _isLoading = false;
    });

    if (email == 'test@example.com' && password == 'password') {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CounterPage()),
        );
      }
    } else if (email.isEmpty || password.isEmpty) {
      setState(() {
        _message = 'Please fill in all fields';
      });
    } else {
      setState(() {
        _message = 'Invalid email or password';
      });
    }
  }

  // Demo 1: Use semantics-based actions (fill, tap)
  void _runSemanticDemo() async {
    debugPrint('=== Running Semantics Demo ===');

    final snapshot = await FlutterMate.snapshot(interactiveOnly: true);
    debugPrint(snapshot.toString());

    // Fill using semantics
    for (final node in snapshot.nodes) {
      if (node.label?.toLowerCase().contains('email') == true) {
        debugPrint('Filling email field: ${node.ref}');
        await FlutterMate.fill(node.ref, 'test@example.com');
      }
      if (node.label?.toLowerCase().contains('password') == true) {
        debugPrint('Filling password field: ${node.ref}');
        await FlutterMate.fill(node.ref, 'password');
      }
    }

    // Find and tap login button
    await Future.delayed(const Duration(milliseconds: 300));
    for (final node in snapshot.nodes) {
      if (node.label?.toLowerCase() == 'login' && node.hasAction('tap')) {
        debugPrint('Tapping login button: ${node.ref}');
        await FlutterMate.tap(node.ref);
        break;
      }
    }
  }

  // Demo 2: Use gesture + keyboard simulation (platform channel)
  void _runGestureKeyboardDemo() async {
    debugPrint('=== Running Gesture & Keyboard Demo ===');
    debugPrint('Simulating REAL keyboard input via platform channels');

    final snapshot = await FlutterMate.snapshot(interactiveOnly: true);
    debugPrint(snapshot.toString());

    // Find the email field and tap on it using gesture simulation
    for (final node in snapshot.nodes) {
      if (node.label?.toLowerCase().contains('email') == true) {
        final center = node.rect.center;
        debugPrint('1. Tapping email field at: (${center.dx}, ${center.dy})');
        FlutterMate.tapAt(center);
        await Future.delayed(const Duration(milliseconds: 300));

        // When we tap a TextField, Flutter creates a new text input connection
        // Connection IDs increment: 1, 2, 3...
        FlutterMate.nextConnection();
        debugPrint(
            '   Connection ID: ${FlutterMate.activeTextInputConnectionId}');

        // Type using platform channel (like a real keyboard)
        debugPrint('2. Typing email via platform channel...');
        final emailTyped = await FlutterMate.typeText('test@example.com');
        debugPrint('   Typed: $emailTyped');
        break;
      }
    }

    await Future.delayed(const Duration(milliseconds: 200));

    // Find and tap password field
    final snapshot2 = await FlutterMate.snapshot(interactiveOnly: true);
    for (final node in snapshot2.nodes) {
      if (node.label?.toLowerCase().contains('password') == true) {
        final center = node.rect.center;
        debugPrint(
            '3. Tapping password field at: (${center.dx}, ${center.dy})');
        FlutterMate.tapAt(center);
        await Future.delayed(const Duration(milliseconds: 300));

        // New field = new connection
        FlutterMate.nextConnection();
        debugPrint(
            '   Connection ID: ${FlutterMate.activeTextInputConnectionId}');

        debugPrint('4. Typing password via platform channel...');
        final pwTyped = await FlutterMate.typeText('password');
        debugPrint('   Typed: $pwTyped');
        break;
      }
    }

    await Future.delayed(const Duration(milliseconds: 200));

    // Find and tap login button
    final snapshot3 = await FlutterMate.snapshot(interactiveOnly: true);
    for (final node in snapshot3.nodes) {
      if (node.label?.toLowerCase() == 'login' && node.hasAction('tap')) {
        debugPrint('5. Tapping Login button: ${node.ref}');
        await FlutterMate.tap(node.ref);
        break;
      }
    }

    debugPrint('=== Demo Complete ===');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy),
            tooltip: 'Semantics Demo',
            onPressed: _runSemanticDemo,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard),
            tooltip: 'Gesture & Keyboard Demo',
            onPressed: _runGestureKeyboardDemo,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome Back',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
              semanticsLabel: 'Welcome Back',
            ),
            const SizedBox(height: 32),
            Semantics(
              label: 'Email input field',
              textField: true,
              child: TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              label: 'Password input field',
              textField: true,
              child: TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
            ),
            const SizedBox(height: 24),
            if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _message,
                  style: TextStyle(
                    color: _message.contains('Invalid') ||
                            _message.contains('Please')
                        ? Colors.red
                        : Colors.green,
                  ),
                  textAlign: TextAlign.center,
                  semanticsLabel: _message,
                ),
              ),
            Semantics(
              label: 'Login button',
              button: true,
              enabled: !_isLoading,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Login', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _message = 'Forgot password clicked';
                });
              },
              child: const Text('Forgot Password?'),
            ),
          ],
        ),
      ),
    );
  }
}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  int _counter = 0;

  void _increment() => setState(() => _counter++);
  void _decrement() => setState(() => _counter--);
  void _reset() => setState(() => _counter = 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Counter'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Counter Value',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Semantics(
              label: 'Counter value: $_counter',
              child: Text(
                '$_counter',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _counter < 0 ? Colors.red : Colors.green,
                    ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Semantics(
                  label: 'Decrement button',
                  button: true,
                  child: FloatingActionButton(
                    heroTag: 'decrement',
                    onPressed: _decrement,
                    tooltip: 'Decrement',
                    child: const Icon(Icons.remove),
                  ),
                ),
                const SizedBox(width: 16),
                Semantics(
                  label: 'Reset button',
                  button: true,
                  child: FloatingActionButton(
                    heroTag: 'reset',
                    onPressed: _reset,
                    tooltip: 'Reset',
                    child: const Icon(Icons.refresh),
                  ),
                ),
                const SizedBox(width: 16),
                Semantics(
                  label: 'Increment button',
                  button: true,
                  child: FloatingActionButton(
                    heroTag: 'increment',
                    onPressed: _increment,
                    tooltip: 'Increment',
                    child: const Icon(Icons.add),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
