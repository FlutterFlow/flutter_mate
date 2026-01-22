import 'package:flutter/material.dart';
import 'package:flutter_mate/flutter_mate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

// ════════════════════════════════════════════════════════════════════════════
// LOGIN PAGE - Tests: tap, fill, focus, pressKey
// ════════════════════════════════════════════════════════════════════════════

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

  void _handleLogin() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));

    final email = _emailController.text;
    final password = _passwordController.text;

    setState(() => _isLoading = false);

    if (email == 'test@example.com' && password == 'password') {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
      }
    } else if (email.isEmpty || password.isEmpty) {
      setState(() => _message = 'Please fill in all fields');
    } else {
      setState(() =>
          _message = 'Invalid credentials. Try: test@example.com / password');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
            ),
            const SizedBox(height: 32),
            Semantics(
              label: 'Email field',
              textField: true,
              child: TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
              onSubmitted: (_) => _handleLogin(),
            ),
            const SizedBox(height: 24),
            if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _message,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            Semantics(
              label: 'Login button',
              button: true,
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
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

// ════════════════════════════════════════════════════════════════════════════
// DASHBOARD - Bottom navigation with 4 tabs
// ════════════════════════════════════════════════════════════════════════════

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  final _pages = const [
    ListPage(),
    FormPage(),
    ActionsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Semantics(
        label: 'Navigation bar',
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.list),
              label: 'List',
            ),
            NavigationDestination(
              icon: Icon(Icons.edit_note),
              label: 'Form',
            ),
            NavigationDestination(
              icon: Icon(Icons.touch_app),
              label: 'Actions',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LIST PAGE - Tests: scroll, tap on list items
// ════════════════════════════════════════════════════════════════════════════

class ListPage extends StatefulWidget {
  const ListPage({super.key});

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  String _selectedItem = '';

  final _items = List.generate(
    30,
    (i) => 'Item ${i + 1}',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scrollable List'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          if (_selectedItem.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.green.shade100,
              child: Semantics(
                label: 'Selected: $_selectedItem',
                child: Text(
                  'Selected: $_selectedItem',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          Expanded(
            child: Semantics(
              label: 'Scrollable item list',
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Semantics(
                    label: item,
                    button: true,
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      title: Text(item),
                      subtitle: Text('Tap to select $item'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        setState(() => _selectedItem = item);
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// FORM PAGE - Tests: toggle (switch/checkbox), select (dropdown), fill, clear
// ════════════════════════════════════════════════════════════════════════════

class FormPage extends StatefulWidget {
  const FormPage({super.key});

  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _newsletter = false;
  bool _notifications = true;
  String _selectedCountry = 'USA';
  double _volume = 50;

  final _countries = ['USA', 'Canada', 'UK', 'Germany', 'France', 'Japan'];

  void _submitForm() {
    final summary = '''
Form Submitted:
- Name: ${_nameController.text}
- Bio: ${_bioController.text}
- Newsletter: $_newsletter
- Notifications: $_notifications
- Country: $_selectedCountry
- Volume: ${_volume.round()}
''';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(summary), duration: const Duration(seconds: 3)),
    );
  }

  void _clearForm() {
    setState(() {
      _nameController.clear();
      _bioController.clear();
      _newsletter = false;
      _notifications = true;
      _selectedCountry = 'USA';
      _volume = 50;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Form Controls'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Text field
            Semantics(
              label: 'Name field',
              textField: true,
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Multi-line text field
            Semantics(
              label: 'Bio field',
              textField: true,
              child: TextField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
            ),
            const SizedBox(height: 24),

            // Checkbox
            Semantics(
              label: 'Newsletter checkbox',
              checked: _newsletter,
              child: CheckboxListTile(
                title: const Text('Subscribe to newsletter'),
                subtitle: const Text('Get weekly updates'),
                value: _newsletter,
                onChanged: (v) => setState(() => _newsletter = v ?? false),
              ),
            ),

            // Switch
            Semantics(
              label: 'Notifications switch',
              toggled: _notifications,
              child: SwitchListTile(
                title: const Text('Push notifications'),
                subtitle: const Text('Receive push notifications'),
                value: _notifications,
                onChanged: (v) => setState(() => _notifications = v),
              ),
            ),
            const SizedBox(height: 16),

            // Dropdown
            Semantics(
              label: 'Country dropdown',
              child: DropdownButtonFormField<String>(
                value: _selectedCountry,
                decoration: const InputDecoration(
                  labelText: 'Country',
                  border: OutlineInputBorder(),
                ),
                items: _countries.map((c) {
                  return DropdownMenuItem(
                    value: c,
                    child: Semantics(label: c, child: Text(c)),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedCountry = v ?? 'USA'),
              ),
            ),
            const SizedBox(height: 24),

            // Slider
            Text('Volume: ${_volume.round()}'),
            Semantics(
              label: 'Volume slider',
              slider: true,
              value: '${_volume.round()}',
              child: Slider(
                value: _volume,
                min: 0,
                max: 100,
                divisions: 10,
                label: _volume.round().toString(),
                onChanged: (v) => setState(() => _volume = v),
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'Clear form button',
                    button: true,
                    child: OutlinedButton(
                      onPressed: _clearForm,
                      child: const Text('Clear'),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Semantics(
                    label: 'Submit form button',
                    button: true,
                    child: ElevatedButton(
                      onPressed: _submitForm,
                      child: const Text('Submit'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ACTIONS PAGE - Tests: longPress, doubleTap, custom gestures
// ════════════════════════════════════════════════════════════════════════════

class ActionsPage extends StatefulWidget {
  const ActionsPage({super.key});

  @override
  State<ActionsPage> createState() => _ActionsPageState();
}

class _ActionsPageState extends State<ActionsPage> {
  String _lastAction = 'None';
  int _tapCount = 0;
  int _doubleTapCount = 0;
  int _longPressCount = 0;

  void _showAction(String action) {
    setState(() => _lastAction = action);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(action),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gesture Actions'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Semantics(
                      label: 'Last action: $_lastAction',
                      child: Text(
                        'Last Action: $_lastAction',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        'Taps: $_tapCount | Double-taps: $_doubleTapCount | Long-presses: $_longPressCount'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Tap button
            Semantics(
              label: 'Tap button',
              button: true,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() => _tapCount++);
                  _showAction('Tap detected!');
                },
                icon: const Icon(Icons.touch_app),
                label: const Text('Tap Me'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(20),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Double-tap area
            Semantics(
              label: 'Double tap area',
              button: true,
              child: GestureDetector(
                onDoubleTap: () {
                  setState(() => _doubleTapCount++);
                  _showAction('Double-tap detected!');
                },
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue, width: 2),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.ads_click, size: 48, color: Colors.blue),
                      SizedBox(height: 8),
                      Text(
                        'Double-Tap Here',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Long-press area
            Semantics(
              label: 'Long press area',
              button: true,
              onLongPress: () {
                setState(() => _longPressCount++);
                _showAction('Long-press detected!');
              },
              child: GestureDetector(
                onLongPress: () {
                  setState(() => _longPressCount++);
                  _showAction('Long-press detected!');
                },
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange, width: 2),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.pan_tool, size: 48, color: Colors.orange),
                      SizedBox(height: 8),
                      Text(
                        'Long-Press Here',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      Text(
                        '(Hold for 500ms)',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Reset button
            Semantics(
              label: 'Reset counters button',
              button: true,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _tapCount = 0;
                    _doubleTapCount = 0;
                    _longPressCount = 0;
                    _lastAction = 'Counters reset';
                  });
                },
                child: const Text('Reset Counters'),
              ),
            ),
            const SizedBox(height: 24),

            // Hover area
            Semantics(
              label: 'Hover area',
              child: _HoverArea(
                onHover: (isHovering) {
                  if (isHovering) {
                    _showAction('Hover entered!');
                  }
                },
              ),
            ),
            const SizedBox(height: 16),

            // Drag area
            const Text('Drag & Drop:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label: 'Draggable item',
                      child: Draggable<String>(
                        data: 'dragged_item',
                        feedback: Material(
                          elevation: 4,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            color: Colors.purple.shade200,
                            child: const Text('Dragging...'),
                          ),
                        ),
                        childWhenDragging: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: const Center(child: Text('(Dragged)')),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.purple, width: 2),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.drag_indicator,
                                    color: Colors.purple),
                                Text('Drag Me',
                                    style: TextStyle(color: Colors.purple)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Semantics(
                      label: 'Drop target',
                      child: DragTarget<String>(
                        onAcceptWithDetails: (details) {
                          _showAction('Item dropped: ${details.data}');
                        },
                        builder: (context, candidateData, rejectedData) {
                          final isHovering = candidateData.isNotEmpty;
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isHovering
                                  ? Colors.green.shade200
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isHovering
                                    ? Colors.green
                                    : Colors.green.shade300,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isHovering
                                        ? Icons.check_circle
                                        : Icons.upload,
                                    color: Colors.green,
                                  ),
                                  Text(
                                    isHovering ? 'Release!' : 'Drop Here',
                                    style: const TextStyle(color: Colors.green),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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

/// Hover-enabled area widget
class _HoverArea extends StatefulWidget {
  final void Function(bool isHovering) onHover;

  const _HoverArea({required this.onHover});

  @override
  State<_HoverArea> createState() => _HoverAreaState();
}

class _HoverAreaState extends State<_HoverArea> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovering = true);
        widget.onHover(true);
      },
      onExit: (_) {
        setState(() => _isHovering = false);
        widget.onHover(false);
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _isHovering ? Colors.green.shade200 : Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovering ? Colors.green : Colors.green.shade300,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              _isHovering ? Icons.visibility : Icons.visibility_off,
              size: 48,
              color: Colors.green,
            ),
            const SizedBox(height: 8),
            Text(
              _isHovering ? 'Hovering!' : 'Hover Over Me',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SETTINGS PAGE - Tests: toggle, navigation, logout
// ════════════════════════════════════════════════════════════════════════════

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _darkMode = false;
  bool _biometrics = true;
  bool _analytics = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Preferences',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Semantics(
            label: 'Dark mode switch',
            toggled: _darkMode,
            child: SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Use dark theme'),
              secondary: const Icon(Icons.dark_mode),
              value: _darkMode,
              onChanged: (v) => setState(() => _darkMode = v),
            ),
          ),
          Semantics(
            label: 'Biometrics switch',
            toggled: _biometrics,
            child: SwitchListTile(
              title: const Text('Biometric Login'),
              subtitle: const Text('Use fingerprint or face'),
              secondary: const Icon(Icons.fingerprint),
              value: _biometrics,
              onChanged: (v) => setState(() => _biometrics = v),
            ),
          ),
          Semantics(
            label: 'Analytics switch',
            toggled: _analytics,
            child: SwitchListTile(
              title: const Text('Send Analytics'),
              subtitle: const Text('Help improve the app'),
              secondary: const Icon(Icons.analytics),
              value: _analytics,
              onChanged: (v) => setState(() => _analytics = v),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Account',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Semantics(
            label: 'Profile button',
            button: true,
            child: ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile tapped')),
                );
              },
            ),
          ),
          Semantics(
            label: 'About button',
            button: true,
            child: ListTile(
              leading: const Icon(Icons.info),
              title: const Text('About'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Flutter Mate Demo',
                  applicationVersion: '1.0.0',
                );
              },
            ),
          ),
          const Divider(),
          Semantics(
            label: 'Logout button',
            button: true,
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
