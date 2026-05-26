import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'home_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showErrorDialog(String title, String message, [String? details]) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (details != null) ...[
              const SizedBox(height: 12),
              Text(
                details,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  List<String> _parseCsvLine(String line) {
    List<String> result = [];
    StringBuffer current = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      var char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString());
    return result;
  }

  Future<void> _login() async {
    final loginId = _emailController.text.trim();
    final password = _passwordController.text;

    if (loginId.isEmpty || password.isEmpty) {
      _showErrorDialog(
        'Missing Fields',
        'Please enter your Email/Employee ID and password.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse(
        'https://docs.google.com/spreadsheets/d/1lkImcQTYrsKBc4eafO6AOyRqlqhXTXnn40gYb4B5jzM/export?format=csv&gid=751895921',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final lines = response.body.split('\n');

        bool userFound = false;
        bool passwordMatched = false;
        String userPermissions = '';
        String userAccessPermissions = '';

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          final columns = _parseCsvLine(line);

          if (columns.length >= 3) {
            final cellEmployeeId = columns[0].trim();
            final cellEmail = columns[1].trim();
            final cellPassword = columns[2].trim();

            if (cellEmployeeId == loginId || cellEmail == loginId) {
              userFound = true;
              if (cellPassword == password) {
                passwordMatched = true;
                if (columns.length > 5) {
                  userPermissions = columns[5].trim();
                }
                if (columns.length > 6) {
                  userAccessPermissions = columns[6].trim();
                }
              }
              break;
            }
          }
        }

        if (!userFound) {
          _showErrorDialog('Login Failed', 'User does not exist.');
        } else if (!passwordMatched) {
          _showErrorDialog('Login Failed', 'Incorrect password.');
        } else {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomeScreen(
                  loginId: loginId,
                  permissions: userPermissions,
                  accessPermissions: userAccessPermissions,
                ),
              ),
            );
          }
        }
      } else {
        _showErrorDialog(
          'Network Error',
          'Failed to fetch data. Status Code: ${response.statusCode}',
        );
      }
    } catch (e) {
      _showErrorDialog('Error', 'An unexpected error occurred.', e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _forgotPassword() async {
    final loginId = _emailController.text.trim();

    if (loginId.isEmpty) {
      _showErrorDialog(
        'Input Required',
        'Please enter your Email or Employee ID to request a password reset.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse(
        'https://docs.google.com/spreadsheets/d/1lkImcQTYrsKBc4eafO6AOyRqlqhXTXnn40gYb4B5jzM/export?format=csv&gid=751895921',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final lines = response.body.split('\n');
        bool userFound = false;

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          final columns = _parseCsvLine(line);

          if (columns.isNotEmpty && columns.length >= 2) {
            final cellEmployeeId = columns[0].trim();
            final cellEmail = columns[1].trim();
            if (cellEmployeeId == loginId || cellEmail == loginId) {
              userFound = true;
              break;
            }
          }
        }

        if (!userFound) {
          _showErrorDialog(
            'User Not Found',
            'No account exists with this Email or Employee ID.',
          );
        } else {
          final updateUrl = Uri.parse('YOUR_GOOGLE_APPS_SCRIPT_WEB_APP_URL');

          if (updateUrl.toString() == 'YOUR_GOOGLE_APPS_SCRIPT_WEB_APP_URL') {
            _showErrorDialog(
              'Backend Required',
              'Please deploy the Google Apps Script and replace the URL in login_page.dart.',
            );
            return;
          }

          final updateResponse = await http.post(
            updateUrl,
            body: {'email': loginId, 'action': 'requesting_password_reset'},
          );

          if (updateResponse.statusCode == 200 ||
              updateResponse.statusCode == 302) {
            _showErrorDialog(
              'Success',
              'Password reset request sent to the admin',
            );
          } else {
            _showErrorDialog('Error', 'Failed to update the Google Sheet.');
          }
        }
      } else {
        _showErrorDialog(
          'Network Error',
          'Failed to verify email. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      _showErrorDialog('Error', 'An unexpected error occurred.', e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Welcome Back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Login to your account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 48),
                  TextField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email or Employee ID',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.lock_outlined, color: Colors.white70),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _forgotPassword,
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF764BA2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF764BA2)),
                            ),
                          )
                        : const Text(
                            'LOG IN',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
