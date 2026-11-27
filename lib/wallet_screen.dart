import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/supabase_db.dart';
import 'dart:math' as math;
import 'withdrawal_screen.dart';
import 'payment_method_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with TickerProviderStateMixin {
  List<AnimationController>? _particleControllers;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  double _balance = 0.0;
  double _thisMonthEarnings = 0.0;
  double _totalEarned = 0.0;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _particleControllers = List.generate(
      8,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(
          milliseconds: 5000 + math.Random(index).nextInt(3000),
        ),
      )..repeat(),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _fadeController.forward();
    _loadWalletData();
  }

  @override
  void dispose() {
    _particleControllers?.forEach((controller) => controller.dispose());
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadWalletData() async {
    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) return;

      // Load wallet balance
      final walletDoc = await SupabaseDb.instance
          .collection('wallets')
          .doc(currentUser.uid)
          .get();

      if (walletDoc.exists) {
        final walletData = walletDoc.data();
        if (walletData != null) {
          _balance = (walletData['balance'] as num?)?.toDouble() ?? 0.0;
          _totalEarned = (walletData['totalEarned'] as num?)?.toDouble() ?? 0.0;
        }
      }

      // Load transactions
      final transactionsSnapshot = await SupabaseDb.instance
          .collection('transactions')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      final List<Map<String, dynamic>> transactions = [];
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      for (var doc in transactionsSnapshot.docs) {
        final data = doc.data();
        final timestamp = parseDbDate(data['timestamp']);
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final type = data['type'] ?? 'earning';

        if (type == 'earning' &&
            timestamp != null &&
            timestamp.toDate().isAfter(monthStart)) {
          _thisMonthEarnings += amount;
        }

        transactions.add({
          'id': doc.id,
          'type': type,
          'amount': amount,
          'description': data['description'] ?? 'Transaction',
          'date': timestamp?.toDate() ?? DateTime.now(),
          'status': data['status'] ?? 'completed',
        });
      }

      if (mounted) {
        setState(() {
          _transactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading wallet data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
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
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: Stack(
          children: [
            ...List.generate(8, (index) => _buildParticle(index)),
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(30),
                            topRight: Radius.circular(30),
                          ),
                        ),
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ListView(
                                padding: const EdgeInsets.all(20),
                                children: [
                                  _buildBalanceCard(),
                                  const SizedBox(height: 20),
                                  _buildQuickActions(),
                                  const SizedBox(height: 30),
                                  _buildSectionTitle('Transaction History'),
                                  const SizedBox(height: 15),
                                  if (_transactions.isEmpty)
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(40),
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons.account_balance_wallet,
                                              size: 80,
                                              color: Colors.grey.shade300,
                                            ),
                                            const SizedBox(height: 20),
                                            const Text(
                                              'No Transactions',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              'Your transaction history will appear here',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    ..._transactions.map(
                                      (transaction) =>
                                          _buildTransactionCard(transaction),
                                    ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 20),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Wallet',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Manage your earnings',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Available Balance',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified, color: Colors.white, size: 16),
                    SizedBox(width: 5),
                    Text(
                      'Verified',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            '\$${_balance.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.trending_up,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'This Month',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                      Text(
                        '\$${_thisMonthEarnings.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Total Earned',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                      Text(
                        '\$${_totalEarned.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            Icons.download,
            'Withdraw',
            Colors.green,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      WithdrawalScreen(availableBalance: _balance),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            Icons.credit_card,
            'Payment Methods',
            Colors.blue,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PaymentMethodScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            Icons.history,
            'History',
            Colors.orange,
            () {
              // Scroll to history section
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final isEarning = transaction['type'] == 'earning';
    final isPending = transaction['status'] == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: isEarning
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isEarning ? Icons.arrow_downward : Icons.arrow_upward,
              color: isEarning ? Colors.green : Colors.red,
              size: 24,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction['description'],
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _formatDate(transaction['date']),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (isPending) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'Pending',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${transaction['amount'] > 0 ? '+' : ''}\$${(transaction['amount'] as double).abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isEarning ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildParticle(int index) {
    if (_particleControllers == null) return const SizedBox.shrink();

    final random = math.Random(index);
    final size = random.nextDouble() * 20 + 5;
    final left = random.nextDouble() * MediaQuery.of(context).size.width;
    final top = random.nextDouble() * 200;

    return Positioned(
      left: left,
      top: top,
      child: AnimatedBuilder(
        animation: _particleControllers![index],
        builder: (context, child) {
          final value = _particleControllers![index].value;
          return Transform.translate(
            offset: Offset(
              math.sin(value * 2 * math.pi) * 20,
              -math.cos(value * 2 * math.pi) * 30,
            ),
            child: Opacity(
              opacity: (0.1 + (math.sin(value * 2 * math.pi) * 0.3)).clamp(
                0.0,
                1.0,
              ),
              child: child,
            ),
          );
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
