import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBuIzr9s3FI2Epm_FoUtGn2tiVkBbGSwEI",
      appId: "1:882938246314:android:teamsyncapp",
      messagingSenderId: "882938246314",
      projectId: "calendar-ce1b8",
      databaseURL: "https://calendar-ce1b8-default-rtdb.firebaseio.com",
    ),
  );
  runApp(const TeamSyncApp());
}

class TeamSyncApp extends StatelessWidget {
  const TeamSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تقويم الفريق',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF6366F1),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          elevation: 0,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  String? _groupCode;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _checkStoredAuth();
  }

  Future<void> _checkStoredAuth() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _groupCode = prefs.getString('teamsync_group');
      _userName = prefs.getString('teamsync_nick');
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
      );
    }
    if (_groupCode != null && _userName != null) {
      return CalendarHomeScreen(groupCode: _groupCode!, userName: _userName!);
    }
    return const LoginCreateScreen();
  }
}

class LoginCreateScreen extends StatefulWidget {
  const LoginCreateScreen({super.key});

  @override
  State<LoginCreateScreen> createState() => _LoginCreateScreenState();
}

class _LoginCreateScreenState extends State<LoginCreateScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _joinCodeController = TextEditingController();
  final _joinNickController = TextEditingController();

  final _createNameController = TextEditingController();
  final _createCodeController = TextEditingController();
  final _createAdminPassController = TextEditingController();
  final _createNickController = TextEditingController();

  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _joinGroup() async {
    final code = _joinCodeController.text.trim();
    final nick = _joinNickController.text.trim();
    if (code.isEmpty || nick.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال رمز المجموعة واسمك');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final db = FirebaseDatabase.instance.ref();
    final snap = await db.child('teams/group_$code/meta').get();

    if (!snap.exists) {
      setState(() {
        _loading = false;
        _errorMessage = 'رمز المجموعة غير موجود! تأكد من الرمز أو أنشئ مجموعة.';
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('teamsync_group', code);
    await prefs.setString('teamsync_nick', nick);

    await db.child('teams/group_$code/members/$nick').set({
      'name': nick,
      'joinedAt': DateTime.now().millisecondsSinceEpoch,
    });

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CalendarHomeScreen(groupCode: code, userName: nick),
        ),
      );
    }
  }

  Future<void> _createGroup() async {
    final name = _createNameController.text.trim();
    final code = _createCodeController.text.trim();
    final adminPass = _createAdminPassController.text.trim();
    final nick = _createNickController.text.trim();

    if (name.isEmpty || code.isEmpty || adminPass.isEmpty || nick.isEmpty) {
      setState(() => _errorMessage = 'يرجى تعبئة جميع الحقول المطلوبة');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final db = FirebaseDatabase.instance.ref();
    final snap = await db.child('teams/group_$code/meta').get();

    if (snap.exists) {
      setState(() {
        _loading = false;
        _errorMessage = 'رمز المجموعة ($code) محجوز بالفعل! اختر رمزاً آخر.';
      });
      return;
    }

    await db.child('teams/group_$code/meta').set({
      'name': name,
      'code': code,
      'adminPass': adminPass,
      'creator': nick,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });

    await db.child('teams/group_$code/members/$nick').set({
      'name': nick,
      'joinedAt': DateTime.now().millisecondsSinceEpoch,
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('teamsync_group', code);
    await prefs.setString('teamsync_nick', nick);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CalendarHomeScreen(groupCode: code, userName: nick),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.alarm_on, size: 50, color: Color(0xFF6366F1)),
                const SizedBox(height: 8),
                const Text(
                  'تقويم الفريق الفوري',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'إنذار فوري يتجاوز وضع الصامت والشاشة مغلقة',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey,
                    tabs: const [
                      Tab(text: 'دخول مجموعة'),
                      Tab(text: 'إنشاء جديدة'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  height: 280,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      Column(
                        children: [
                          TextField(
                            controller: _joinCodeController,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              labelText: 'رمز المجموعة',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _joinNickController,
                            decoration: const InputDecoration(
                              labelText: 'اسمك في الفريق',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                              ),
                              onPressed: _loading ? null : _joinGroup,
                              child: _loading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text('دخول المجموعة', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      SingleChildScrollView(
                        child: Column(
                          children: [
                            TextField(
                              controller: _createNameController,
                              decoration: const InputDecoration(
                                labelText: 'اسم المجموعة',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _createCodeController,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                labelText: 'رمز المجموعة المطلوب',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _createAdminPassController,
                              obscureText: true,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                labelText: 'رمز المشرف السري (لحذف المواعيد)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _createNickController,
                              decoration: const InputDecoration(
                                labelText: 'اسمك (المشرف المؤسس)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                                onPressed: _loading ? null : _createGroup,
                                child: _loading
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Text('إنشاء وتثبيت المجموعة', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CalendarHomeScreen extends StatefulWidget {
  final String groupCode;
  final String userName;

  const CalendarHomeScreen({
    super.key,
    required this.groupCode,
    required this.userName,
  });

  @override
  State<CalendarHomeScreen> createState() => _CalendarHomeScreenState();
}

class _CalendarHomeScreenState extends State<CalendarHomeScreen> {
  late DatabaseReference _eventsRef;
  late DatabaseReference _membersRef;
  late DatabaseReference _metaRef;

  bool _isAlarmRinging = false;
  String _alarmTitle = '';
  Timer? _vibrationTimer;
  StreamSubscription? _childAddedSub;

  @override
  void initState() {
    super.initState();
    final db = FirebaseDatabase.instance.ref();
    _eventsRef = db.child('teams/group_${widget.groupCode}/events');
    _membersRef = db.child('teams/group_${widget.groupCode}/members');
    _metaRef = db.child('teams/group_${widget.groupCode}/meta');

    _listenToCriticalEvents();
  }

  void _listenToCriticalEvents() {
    bool isInitial = true;
    _childAddedSub = _eventsRef.limitToLast(1).onChildAdded.listen((event) {
      if (isInitial) return;
      final val = event.snapshot.value as Map?;
      if (val != null && val['priority'] == 'critical' && val['creator'] != widget.userName) {
        _triggerContinuousAlarm(val['title'] ?? 'موعد طارئ');
      }
    });

    Future.delayed(const Duration(seconds: 2), () {
      isInitial = false;
    });
  }

  void _triggerContinuousAlarm(String title) {
    setState(() {
      _isAlarmRinging = true;
      _alarmTitle = title;
    });

    FlutterRingtonePlayer.playAlarm(
      looping: true,
      volume: 1.0,
      asAlarm: true,
    );

    _vibrationTimer?.cancel();
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      Vibration.vibrate(pattern: [0, 400, 200, 400]);
    });
  }

  void _stopAlarm() {
    FlutterRingtonePlayer.stop();
    _vibrationTimer?.cancel();
    setState(() {
      _isAlarmRinging = false;
    });
  }

  void _testAlarm() {
    _triggerContinuousAlarm("تجربة منبه الطوارئ الشغال بالصامت");
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginCreateScreen()),
      );
    }
  }

  void _openAddEventDialog() {
    final titleCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = const TimeOfDay(hour: 12, minute: 0);
    String priority = 'critical';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إضافة موعد جديد للتيم', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'عنوان الموعد',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFF334155)),
                      ),
                      leading: const Icon(Icons.calendar_month, color: Color(0xFF6366F1)),
                      title: Text('التاريخ: ${DateFormat('yyyy-MM-dd').format(selectedDate)}'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFF334155)),
                      ),
                      leading: const Icon(Icons.access_time, color: Color(0xFF6366F1)),
                      title: Text('الوقت: ${selectedTime.format(context)}'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setModalState(() => selectedTime = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: priority,
                      decoration: const InputDecoration(
                        labelText: 'نوع التنبيه',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'critical',
                          child: Text('🚨 حرج (يكسر الصامت ويرن عند التيم فوراً)'),
                        ),
                        DropdownMenuItem(
                          value: 'normal',
                          child: Text('📅 عادي (موعد تقويم بدون منبه حرج)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => priority = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                        onPressed: () {
                          if (titleCtrl.text.trim().isEmpty) return;
                          _eventsRef.push().set({
                            'title': titleCtrl.text.trim(),
                            'date': DateFormat('yyyy-MM-dd').format(selectedDate),
                            'time': selectedTime.format(context),
                            'priority': priority,
                            'creator': widget.userName,
                            'timestamp': DateTime.now().millisecondsSinceEpoch,
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('نشر الموعد عند الجميع', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openAdminPanel() {
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('دخول لوحة المشرف'),
          content: TextField(
            controller: passCtrl,
            obscureText: true,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              labelText: 'رمز المشرف السري',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final snap = await _metaRef.get();
                final meta = snap.value as Map?;
                if (meta != null && meta['adminPass'] == passCtrl.text.trim()) {
                  Navigator.pop(ctx);
                  _showAdminDashboard();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('رمز المشرف غير صحيح!')),
                  );
                }
              },
              child: const Text('تحقق'),
            ),
          ],
        );
      },
    );
  }

  void _showAdminDashboard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('إدارة أعضاء ومواعيد المجموعة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder(
                  stream: _membersRef.onValue,
                  builder: (context, AsyncSnapshot<DatabaseEvent> snap) {
                    if (!snap.hasData || snap.data!.snapshot.value == null) {
                      return const Center(child: Text('لا يوجد أعضاء'));
                    }
                    final members = Map<String, dynamic>.from(snap.data!.snapshot.value as Map);
                    return ListView(
                      children: members.keys.map((name) {
                        return ListTile(
                          title: Text(name),
                          trailing: IconButton(
                            icon: const Icon(Icons.person_remove, color: Colors.red),
                            onPressed: () {
                              _membersRef.child(name).remove();
                            },
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _childAddedSub?.cancel();
    _vibrationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('مجموعة: ${widget.groupCode}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: _openAdminPanel,
            tooltip: 'لوحة المشرف',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'خروج',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isAlarmRinging)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.red.withOpacity(0.9),
              child: Column(
                children: [
                  const Icon(Icons.warning, size: 40, color: Colors.white),
                  const SizedBox(height: 4),
                  const Text('🚨 موعد طارئ يرن الآن!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(_alarmTitle, style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                    onPressed: _stopAlarm,
                    child: const Text('إيقاف الرنين وكتم المنبه', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF334155),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.volume_up, size: 18),
                    label: const Text('تجربة رنين الصامت', style: TextStyle(fontSize: 12)),
                    onPressed: _testAlarm,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _eventsRef.onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return const Center(child: Text('لا توجد مواعيد بعد. اضغط + لإضافة موعد.'));
                }
                final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
                final list = data.entries.toList().reversed.toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) {
                    final item = Map<String, dynamic>.from(list[i].value as Map);
                    final isCrit = item['priority'] == 'critical';
                    return Card(
                      color: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isCrit ? Colors.red : const Color(0xFF6366F1),
                          width: 1.5,
                        ),
                      ),
                      child: ListTile(
                        title: Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('📅 ${item['date']} • ⏰ ${item['time']}\nبواسطة: ${item['creator']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.grey),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (dCtx) {
                                final pCtrl = TextEditingController();
                                return AlertDialog(
                                  backgroundColor: const Color(0xFF1E293B),
                                  title: const Text('حذف الموعد'),
                                  content: TextField(
                                    controller: pCtrl,
                                    obscureText: true,
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(labelText: 'رمز المشرف لحذف الموعد'),
                                  ),
                                  actions: [
                                    ElevatedButton(
                                      onPressed: () async {
                                        final snap = await _metaRef.get();
                                        final meta = snap.value as Map?;
                                        if (meta != null && meta['adminPass'] == pCtrl.text.trim()) {
                                          _eventsRef.child(list[i].key).remove();
                                          Navigator.pop(dCtx);
                                        }
                                      },
                                      child: const Text('حذف'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6366F1),
        onPressed: _openAddEventDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
