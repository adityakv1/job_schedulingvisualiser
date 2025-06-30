import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:graphview/GraphView.dart';

void main() {
  runApp(JobAssignmentApp());
}

class JobAssignmentApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advanced Job Assignment Solver',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey[50],
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: TextTheme(
          headlineSmall: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.indigo[900]),
          titleLarge: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    CostMatrixInputPage(),
    HistoryPage(),
  ];

  final List<String> _titles = [
    'Algorithm Solver',
    'Execution History',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex],
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.calculate),
            label: 'Solver',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}

class Algorithm {
  final String id;
  final String name;
  final String description;
  final String timeComplexity;
  final bool guaranteesOptimal;
  final bool handlesConstraints;

  Algorithm({
    required this.id,
    required this.name,
    required this.description,
    required this.timeComplexity,
    required this.guaranteesOptimal,
    required this.handlesConstraints,
  });

  factory Algorithm.fromJson(Map<String, dynamic> json) {
    return Algorithm(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      timeComplexity: json['time_complexity'],
      guaranteesOptimal: json['guarantees_optimal'],
      handlesConstraints: json['handles_constraints'],
    );
  }
}

class CostMatrixInputPage extends StatefulWidget {
  @override
  _CostMatrixInputPageState createState() => _CostMatrixInputPageState();
}

class _CostMatrixInputPageState extends State<CostMatrixInputPage> {
  int size = 3;
  List<List<TextEditingController>> controllers = [];
  List<TextEditingController> workerCapacityControllers = [];
  List<TextEditingController> machineTimeControllers = [];
  
  String result = "";
  bool isLoading = false;
  bool showConstraints = false;
  
  List<Algorithm> algorithms = [];
  Algorithm? selectedAlgorithm;
  Map<String, dynamic>? analysisData;
  Map<String, dynamic>? algorithmData;
  int? executionId;

  @override
  void initState() {
    super.initState();
    _generateControllers();
    _loadAlgorithms();
  }

  void _generateControllers() {
    controllers = List.generate(
        size, (i) => List.generate(size, (j) => TextEditingController()));
    workerCapacityControllers = List.generate(size, (i) => TextEditingController(text: "1"));
    machineTimeControllers = List.generate(size, (i) => TextEditingController(text: "1"));
  }

  Future<void> _loadAlgorithms() async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:5000/algorithms'),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body) as List;
        setState(() {
          algorithms = data.map((a) => Algorithm.fromJson(a)).toList();
          selectedAlgorithm = algorithms.first;
        });
      }
    } catch (e) {
      print("Error loading algorithms: $e");
    }
  }

  void _updateSize(int? newSize) {
    if (newSize != null && newSize != size) {
      setState(() {
        size = newSize;
        _generateControllers();
        result = "";
        analysisData = null;
        algorithmData = null;
      });
    }
  }

  Future<void> _submitMatrix() async {
    if (selectedAlgorithm == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select an algorithm')),
      );
      return;
    }

    setState(() {
      isLoading = true;
      result = "";
      analysisData = null;
      algorithmData = null;
    });

    List<List<int>> matrix = controllers
        .map((row) => row
            .map((controller) => int.tryParse(controller.text) ?? 0)
            .toList())
        .toList();

    Map<String, dynamic> requestBody = {
      'matrix': matrix,
      'algorithm': selectedAlgorithm!.id,
    };

    // Add constraints if they're enabled and algorithm supports them
    if (showConstraints && selectedAlgorithm!.handlesConstraints) {
      requestBody['worker_capacities'] = workerCapacityControllers
          .map((c) => int.tryParse(c.text) ?? 1)
          .toList();
      requestBody['machine_times'] = machineTimeControllers
          .map((c) => int.tryParse(c.text) ?? 1)
          .toList();
    }

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/solve'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        setState(() {
          result = "✅ Solution found successfully!";
          analysisData = data['analysis'];
          algorithmData = data['algorithm_data'];
          executionId = data['execution_id'];
        });
      } else {
        setState(() {
          result = "❌ Error: ${response.reasonPhrase}";
        });
      }
    } catch (e) {
      setState(() {
        result = "❌ Error: Could not connect to the server.";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildAlgorithmSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Select Algorithm",
                style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 12),
            if (algorithms.isNotEmpty)
              DropdownButtonFormField<Algorithm>(
                value: selectedAlgorithm,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: algorithms.map((algorithm) {
                  return DropdownMenuItem(
                    value: algorithm,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(algorithm.name, style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(algorithm.timeComplexity, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (Algorithm? value) {
                  setState(() {
                    selectedAlgorithm = value;
                    showConstraints = value?.handlesConstraints ?? false;
                  });
                },
              ),
            if (selectedAlgorithm != null) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(selectedAlgorithm!.description,
                        style: TextStyle(fontSize: 14)),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          selectedAlgorithm!.guaranteesOptimal 
                              ? Icons.check_circle 
                              : Icons.info,
                          size: 16,
                          color: selectedAlgorithm!.guaranteesOptimal 
                              ? Colors.green 
                              : Colors.orange,
                        ),
                        SizedBox(width: 4),
                        Text(
                          selectedAlgorithm!.guaranteesOptimal 
                              ? "Guarantees optimal solution" 
                              : "Heuristic (may not be optimal)",
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    if (selectedAlgorithm!.handlesConstraints) ...[
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.settings, size: 16, color: Colors.blue),
                          SizedBox(width: 4),
                          Text("Supports capacity constraints",
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConstraintsSection() {
    if (!showConstraints || selectedAlgorithm?.handlesConstraints != true) {
      return SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Capacity Constraints",
                style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Worker Capacities (hours)",
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      ...List.generate(size, (i) => Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: workerCapacityControllers[i],
                          decoration: InputDecoration(
                            labelText: 'Worker ${i+1}',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      )),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Machine Times (hours)",
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      ...List.generate(size, (i) => Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: machineTimeControllers[i],
                          decoration: InputDecoration(
                            labelText: 'Machine ${i+1}',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisSection() {
    if (analysisData == null) return SizedBox.shrink();

    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.green[700]),
                SizedBox(width: 8),
                Text("Analysis Results",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.green[700])),
              ],
            ),
            Divider(color: Colors.green[300]),
            SizedBox(height: 12),
            
            // Algorithm and Performance Metrics
            Row(
              children: [
                Expanded(
                  child: _buildAnalysisItem("Algorithm Used", 
                      analysisData!['algorithm_used'], Icons.smart_toy),
                ),
                Expanded(
                  child: _buildAnalysisItem("Execution Time", 
                      "${analysisData!['execution_time_ms']} ms", Icons.timer),
                ),
              ],
            ),
            SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildAnalysisItem("Time Complexity", 
                      analysisData!['time_complexity'], Icons.trending_up),
                ),
                Expanded(
                  child: _buildAnalysisItem("Matrix Size", 
                      "${analysisData!['matrix_size']}×${analysisData!['matrix_size']}", Icons.grid_4x4),
                ),
              ],
            ),
            SizedBox(height: 16),
            
            // Solution Results
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Solution Results", 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 8),
                  Text("Optimal Cost: ${analysisData!['optimal_cost']}", 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[700])),
                  SizedBox(height: 8),
                  Text("Assignment:", style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  ...List.generate(analysisData!['assignment'].length, (i) {
                    int job = analysisData!['assignment'][i];
                    return Padding(
                      padding: EdgeInsets.only(left: 16, bottom: 2),
                      child: Text("Worker ${i+1} → Job ${job+1}"),
                    );
                  }),
                ],
              ),
            ),
            
            SizedBox(height: 16),
            Row(
              children: [
                if (selectedAlgorithm?.id == 'branch_bound' && algorithmData != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.account_tree),
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => TreeViewPage(
                              treeData: algorithmData!['tree'],
                              optimalPath: analysisData!['assignment']),
                        ));
                      },
                      label: Text("View Tree"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                if (selectedAlgorithm?.id != 'branch_bound')
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.visibility),
                      onPressed: () {
                        _showAlgorithmDetails();
                      },
                      label: Text("View Details"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.history),
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => ExecutionDetailPage(executionId: executionId!),
                      ));
                    },
                    label: Text("View in History"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
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

  Widget _buildAnalysisItem(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green[600]),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(value, style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAlgorithmDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${selectedAlgorithm!.name} Details"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectedAlgorithm!.id == 'min_cost_max_flow' && algorithmData != null) ...[
                Text("Flow Steps:", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                ...((algorithmData!['flow_steps'] ?? []) as List).map((step) => 
                  Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text("• ${step['action']}: ${step.toString()}"),
                  )).toList(),
              ],
              if (selectedAlgorithm!.id == 'ilp' && algorithmData != null) ...[
                Text("ILP Solution:", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text("Status: ${algorithmData!['status']}"),
                SizedBox(height: 8),
                Text("Solution Details:", style: TextStyle(fontWeight: FontWeight.bold)),
                ...((algorithmData!['solution_details'] ?? []) as List).map((detail) =>
                  Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text("• Worker ${detail['worker']} → Job ${detail['job']} (Cost: ${detail['cost']})"),
                  )).toList(),
              ],
              if (selectedAlgorithm!.id == 'greedy' && algorithmData != null) ...[
                Text("Greedy Steps:", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                ...((algorithmData!['greedy_steps'] ?? []) as List).map((step) =>
                  Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text("${step['step']}. Worker ${step['worker']} → Job ${step['job']} (Cost: ${step['cost']}, Efficiency: ${step['efficiency']})"),
                  )).toList(),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAlgorithmSelector(),
          SizedBox(height: 16),
          _buildConstraintsSection(),
          SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Matrix Size:",
                          style: Theme.of(context).textTheme.titleLarge),
                      DropdownButton<int>(
                        value: size,
                        onChanged: _updateSize,
                        items: [2, 3, 4, 5]
                            .map((e) => DropdownMenuItem(
                                value: e, child: Text('$e × $e')))
                            .toList(),
                        style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 16),
                        underline: Container(
                          height: 2,
                          color: Theme.of(context).primaryColorDark,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  Text("Enter Cost Matrix",
                      style: Theme.of(context).textTheme.titleLarge),
                  SizedBox(height: 16),
                  Table(
                    border: TableBorder.all(
                        color: Colors.indigo.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8)),
                    children: List.generate(
                      size,
                      (i) => TableRow(
                        children: List.generate(
                          size,
                          (j) => Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: TextField(
                              controller: controllers[i][j],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                hintText: '0',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.indigo,
                  Colors.indigo.shade700,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.indigo.withOpacity(0.4),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                )
              ],
            ),
            child: ElevatedButton(
              onPressed: isLoading ? null : _submitMatrix,
              child: isLoading
                  ? CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                  : Text("Solve with ${selectedAlgorithm?.name ?? 'Algorithm'}",
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          SizedBox(height: 24),
          if (result.isNotEmpty)
            Card(
              color: result.startsWith("❌")
                  ? Colors.red.shade100
                  : Colors.green.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(result,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          if (analysisData != null) ...[
            SizedBox(height: 16),
            _buildAnalysisSection(),
          ],
        ],
      ),
    );
  }
}

class HistoryPage extends StatefulWidget {
  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<dynamic> history = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:5000/history'),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        setState(() {
          history = data['history'];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading history: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text("No executions yet",
                style: Theme.of(context).textTheme.headlineSmall),
            Text("Solve some problems to see them here!"),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final execution = history[history.length - 1 - index]; // Show newest first
        return Card(
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.indigo,
              child: Text("${execution['id']}", style: TextStyle(color: Colors.white)),
            ),
            title: Text("${execution['algorithm'].toString().replaceAll('_', ' ').toUpperCase()}"),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Matrix: ${execution['matrix_size']} | Cost: ${execution['optimal_cost']}"),
                Text("Time: ${execution['execution_time_ms']} ms | ${execution['timestamp'].toString().substring(0, 19)}"),
              ],
            ),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => ExecutionDetailPage(executionId: execution['id']),
              ));
            },
          ),
        );
      },
    );
  }
}

class ExecutionDetailPage extends StatefulWidget {
  final int executionId;

  ExecutionDetailPage({required this.executionId});

  @override
  _ExecutionDetailPageState createState() => _ExecutionDetailPageState();
}

class _ExecutionDetailPageState extends State<ExecutionDetailPage> {
  Map<String, dynamic>? execution;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExecution();
  }

  Future<void> _loadExecution() async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:5000/history/${widget.executionId}'),
      );

      if (response.statusCode == 200) {
        setState(() {
          execution = jsonDecode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text("Loading...")),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (execution == null) {
      return Scaffold(
        appBar: AppBar(title: Text("Error")),
        body: Center(child: Text("Execution not found")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Execution #${execution!['id']}"),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Execution Summary", 
                        style: Theme.of(context).textTheme.titleLarge),
                    Divider(),
                    _buildDetailRow("Algorithm", execution!['algorithm'].toString().replaceAll('_', ' ').toUpperCase()),
                    _buildDetailRow("Matrix Size", execution!['matrix_size']),
                    _buildDetailRow("Execution Time", "${execution!['execution_time_ms']} ms"),
                    _buildDetailRow("Time Complexity", execution!['time_complexity']),
                    _buildDetailRow("Optimal Cost", execution!['optimal_cost'].toString()),
                    _buildDetailRow("Timestamp", execution!['timestamp'].toString().substring(0, 19)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Assignment Result", 
                        style: Theme.of(context).textTheme.titleLarge),
                    Divider(),
                    ...List.generate(execution!['assignment'].length, (i) {
                      int job = execution!['assignment'][i];
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.person, size: 20),
                            SizedBox(width: 8),
                            Text("Worker ${i+1}"),
                            Icon(Icons.arrow_forward, size: 16),
                            Icon(Icons.work, size: 20),
                            SizedBox(width: 8),
                            Text("Job ${job+1}"),
                            Spacer(),
                            Text("Cost: ${execution!['matrix'][i][job]}"),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Cost Matrix", 
                        style: Theme.of(context).textTheme.titleLarge),
                    Divider(),
                    Table(
                      border: TableBorder.all(color: Colors.grey[300]!),
                      children: List.generate(execution!['matrix'].length, (i) =>
                        TableRow(
                          children: List.generate(execution!['matrix'][i].length, (j) =>
                            Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                execution!['matrix'][i][j].toString(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: execution!['assignment'][i] == j 
                                      ? FontWeight.bold 
                                      : FontWeight.normal,
                                  color: execution!['assignment'][i] == j 
                                      ? Colors.green[700] 
                                      : Colors.black,
                                ),
                              ),
                            ),
                          ),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

// Keep the existing TreeViewPage class for Branch and Bound visualization
class TreeViewPage extends StatelessWidget {
  final Map<String, dynamic> treeData;
  final List<dynamic> optimalPath;
  final Graph graph = Graph();
  final BuchheimWalkerConfiguration builder = BuchheimWalkerConfiguration();

  TreeViewPage(
      {Key? key, required this.treeData, required this.optimalPath})
      : super(key: key) {
    _buildGraph(treeData, null);
    builder
      ..siblingSeparation = (60)
      ..levelSeparation = (80)
      ..subtreeSeparation = (60)
      ..orientation = (BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM);
  }

  void _buildGraph(Map<String, dynamic> nodeData, Map<String, dynamic>? parentData) {
    var node = Node.Id(nodeData['id']);
    graph.addNode(node);

    if (parentData != null) {
      var parentNode = Node.Id(parentData['id']);
      bool isParentOptimal = _isNodeOnPath(parentData);
      bool isCurrentOptimal = _isNodeOnPath(nodeData);

      graph.addEdge(
        parentNode,
        node,
        paint: Paint()
          ..color = (isParentOptimal && isCurrentOptimal)
              ? Colors.green.shade600
              : Colors.red.shade400
          ..strokeWidth = (isParentOptimal && isCurrentOptimal) ? 2.5 : 1,
      );
    }

    if (nodeData['children'] != null) {
      for (var childData in nodeData['children']) {
        _buildGraph(childData as Map<String, dynamic>, nodeData);
      }
    }
  }
  
  bool _isNodeOnPath(Map<String, dynamic> nodeData) {
    List<dynamic> nodePath = nodeData['path'] ?? [];
    if (nodePath.isEmpty) return true;
    if (nodePath.length > optimalPath.length) return false;
    for (int i = 0; i < nodePath.length; i++) {
      if (nodePath[i] != optimalPath[i]) {
        return false;
      }
    }
    return true;
  }

  Map<String, dynamic>? _findNodeData(
      Map<String, dynamic> currentNode, int targetId) {
    if (currentNode['id'] == targetId) {
      return currentNode;
    }
    if (currentNode['children'] != null) {
      for (var child in currentNode['children']) {
        var result = _findNodeData(child, targetId);
        if (result != null) return result;
      }
    }
    return null;
  }

  Widget _buildNodeWidget(int id) {
    var nodeInfo = _findNodeData(treeData, id)!;
    bool isOnOptimalPath = _isNodeOnPath(nodeInfo);
    
    final optimalColor = Colors.green.shade600;
    final nonOptimalColor = Colors.orange.shade600;

    return Card(
      elevation: 6,
      color: isOnOptimalPath ? optimalColor.withOpacity(0.15) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isOnOptimalPath ? optimalColor : nonOptimalColor,
          width: isOnOptimalPath ? 2 : 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Node: ${nodeInfo['id']}',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isOnOptimalPath ? optimalColor : nonOptimalColor),
            ),
            Divider(color: Colors.grey[300]),
            _buildInfoRow('Cost', '${nodeInfo['cost']}', isOnOptimalPath),
            _buildInfoRow('Bound', '${nodeInfo['bound']}', isOnOptimalPath),
            _buildInfoRow('Path', '${nodeInfo['path']}', isOnOptimalPath),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isOptimal) {
    final textColor = isOptimal ? Colors.black87 : Colors.grey[700];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 12, color: textColor),
          children: [
            TextSpan(
                text: '$label: ',
                style: TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo[50],
      appBar: AppBar(
        title: Text("State Space Tree"),
      ),
      body: InteractiveViewer(
        constrained: false,
        boundaryMargin: EdgeInsets.all(100),
        minScale: 0.1,
        maxScale: 2.5,
        child: GraphView(
          graph: graph,
          algorithm:
              BuchheimWalkerAlgorithm(builder, TreeEdgeRenderer(builder)),
          builder: (Node node) {
            var nodeId = node.key!.value as int;
            return _buildNodeWidget(nodeId);
          },
        ),
      ),
    );
  }
}