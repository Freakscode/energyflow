import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:energyflow/main.dart';
import 'package:energyflow/pages/signup_page.dart';
import 'package:energyflow/pages/dashboard_page.dart';
import 'package:energyflow/pages/onhold_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  bool _redirecting = false;
  final _supabase = Supabase.instance.client;

  late final TextEditingController _emailController = TextEditingController();
  late final TextEditingController _passwordController = TextEditingController();
  late final StreamSubscription<AuthState> _authStateSuscription;

  Future<void> _signIn() async {
    try {
      setState(() {
        _isLoading = true;
      });
      await _supabase.auth.signInWithPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (mounted) {
        _emailController.clear();
        _passwordController.clear();
      }
    } on AuthException catch (error) {
      if (mounted) context.showSnackBar(error.message, isError: true);
    } catch (error) {
      if (mounted) {
        context.showSnackBar('Ha ocurrido un error inesperado', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    _authStateSuscription = _supabase.auth.onAuthStateChange.listen(
      (data) async {
        if (_redirecting) return;
        final session = data.session;
        if (session != null) {
          _redirecting = true;
          final userType = await _getUserType(session.user);
          if (mounted) {
            if (userType == 'onHold') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const OnholdPage()),
              );
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const MainDashboard()),
              );
            }
          }
        }
      },
      onError: (error) {
        if (mounted) {
          if (error is AuthException) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message), backgroundColor: Colors.red));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unexpected error occurred'), backgroundColor: Colors.red));
          }
        }
      },
    );
    super.initState();
  }

  Future<String?> _getUserType(User user) async {
    try {
      final userMetadata = user.userMetadata;
      if (userMetadata != null && userMetadata.containsKey('type')) {
        return userMetadata['type'] as String?;
      }
      return null;
    } catch (e) {
      print('Error fetching user type: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _authStateSuscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar Sesión')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Iniciar Sesión',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Correo Electrónico',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(_isLoading ? 'Iniciando Sesión...' : 'Iniciar Sesión'),
                  ),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const SignUpPage()),
                      );
                    },
                    child: const Text('Crear Cuenta'),
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