import 'package:flutter/cupertino.dart';
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
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(message),
            if (details != null) ...[
              const SizedBox(height: 12),
              Text(
                details,
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ],
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
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
      // Fetching the public CSV export of the Google Sheet
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

        // Skip the header row if there is one (assuming first row is headers)
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          final columns = _parseCsvLine(line);

          if (columns.length >= 3) {
            // Trim whitespaces from the parsed CSV data
            final cellEmployeeId = columns[0].trim();
            final cellEmail = columns[1].trim();
            final cellPassword = columns[2].trim();

            if (cellEmployeeId == loginId || cellEmail == loginId) {
              userFound = true;
              if (cellPassword == password) {
                passwordMatched = true;
                // Permissions is at Column F (index 5)
                if (columns.length > 5) {
                  userPermissions = columns[5].trim();
                }
                // Access Permissions is at Column G (index 6)
                if (columns.length > 6) {
                  userAccessPermissions = columns[6].trim();
                }
              }
              break; // Stop searching once the user is found
            }
          }
        }

        if (!userFound) {
          _showErrorDialog('Login Failed', 'User does not exist.');
        } else if (!passwordMatched) {
          _showErrorDialog('Login Failed', 'Incorrect password.');
        } else {
          // Success! Navigate to the home screen
          if (mounted) {
            Navigator.pushReplacement(
              context,
              CupertinoPageRoute(
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
        // HTTP Error handling (e.g. 401 if sheet is not public)
        _showErrorDialog(
          'Network Error',
          'Failed to fetch data. Ensure your Google Sheet is set to "Anyone with the link can view". Status Code: ${response.statusCode}',
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
      // 1. Verify that the user exists in the sheet first
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
          // 2. The user exists.
          // Note: Updating a Google Sheet directly from the app securely requires an API endpoint (e.g. Google Apps Script Web App).
          // Replace this URL with your deployed Google Apps Script Web App URL from the walkthrough artifact.
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
    return CupertinoPageScaffold(
      child: Container(
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
                    CupertinoIcons.lock_shield,
                    size: 80,
                    color: CupertinoColors.white,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Welcome Back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.white,
                      letterSpacing: 1.2,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Login to your account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: CupertinoColors.white.withValues(alpha: 0.7),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 48),
                  CupertinoTextField(
                    controller: _emailController,
                    style: const TextStyle(color: CupertinoColors.white),
                    keyboardType: TextInputType.emailAddress,
                    placeholder: 'Email or Employee ID',
                    placeholderStyle: TextStyle(
                      color: CupertinoColors.white.withValues(alpha: 0.5),
                    ),
                    prefix: Padding(
                      padding: const EdgeInsets.only(left: 16.0, right: 8.0),
                      child: Icon(
                        CupertinoIcons.mail,
                        color: CupertinoColors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: CupertinoColors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CupertinoTextField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    style: const TextStyle(color: CupertinoColors.white),
                    placeholder: 'Password',
                    placeholderStyle: TextStyle(
                      color: CupertinoColors.white.withValues(alpha: 0.5),
                    ),
                    prefix: Padding(
                      padding: const EdgeInsets.only(left: 16.0, right: 8.0),
                      child: Icon(
                        CupertinoIcons.lock,
                        color: CupertinoColors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    suffix: CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Icon(
                        _isPasswordVisible
                            ? CupertinoIcons.eye
                            : CupertinoIcons.eye_slash,
                        color: CupertinoColors.white.withValues(alpha: 0.7),
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: CupertinoColors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _isLoading ? null : _forgotPassword,
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  CupertinoButton(
                    onPressed: _isLoading ? null : _login,
                    color: CupertinoColors.white,
                    disabledColor: CupertinoColors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: _isLoading
                        ? const CupertinoActivityIndicator()
                        : const Text(
                            'LOG IN',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: Color(0xFF764BA2),
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
