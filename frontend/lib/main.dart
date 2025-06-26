import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// Make sure you have added 'graphview: ^1.2.0' (or the latest version)
// to your pubspec.yaml file and run 'flutter pub get'.
import 'package:graphview/GraphView.dart';

void main() {
  runApp(JobAssignmentApp());
}

class JobAssignmentApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Job Assignment Solver',
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
      home: CostMatrixInputPage(),
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
  String result = "";
  bool isLoading = false;
  Map<String, dynamic>? treeData;
  // UPDATE: Store the optimal path from the backend response.
  List<dynamic>? bestAssignment;

  @override
  void initState() {
    super.initState();
    _generateControllers();
  }

  void _generateControllers() {
    controllers = List.generate(
        size, (i) => List.generate(size, (j) => TextEditingController()));
  }

  void _updateSize(int? newSize) {
    if (newSize != null && newSize != size) {
      setState(() {
        size = newSize;
        _generateControllers();
        result = "";
        treeData = null;
        bestAssignment = null;
      });
    }
  }

  Future<void> _submitMatrix() async {
    setState(() {
      isLoading = true;
      result = "";
      treeData = null;
      bestAssignment = null;
    });

    List<List<int>> matrix = controllers
        .map((row) => row
            .map((controller) => int.tryParse(controller.text) ?? 0)
            .toList())
        .toList();

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/solve'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'matrix': matrix}),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        setState(() {
          result =
              "Optimal Cost: ${data['cost']}\nAssignment: ${data['assignment']}";
          treeData = data['tree'];
          // UPDATE: Save the optimal path.
          bestAssignment = data['assignment'];
        });
      } else {
        setState(() {
          result = "Error: ${response.reasonPhrase}";
        });
      }
    } catch (e) {
      setState(() {
        result = "Error: Could not connect to the server.";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Job Assignment Solver',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                    : Text("Solve & Generate Tree",
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
                color: result.startsWith("Error")
                    ? Colors.red.shade100
                    : Colors.green.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(result,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      // UPDATE: Ensure we have an optimal path before showing the button.
                      if (treeData != null && bestAssignment != null) ...[
                        SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: Icon(Icons.account_tree_outlined),
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => TreeViewPage(
                                  treeData: treeData!,
                                  optimalPath: bestAssignment!),
                            ));
                          },
                          label: Text("View State Space Tree"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: result.startsWith("Error")
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                            foregroundColor: Colors.white,
                          ),
                        )
                      ]
                    ],
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}

class TreeViewPage extends StatelessWidget {
  final Map<String, dynamic> treeData;
  // UPDATE: Store the optimal path to use for coloring.
  final List<dynamic> optimalPath;
  final Graph graph = Graph();
  final BuchheimWalkerConfiguration builder = BuchheimWalkerConfiguration();

  TreeViewPage(
      {Key? key, required this.treeData, required this.optimalPath})
      : super(key: key) {
    // Pass parent data down recursively to determine edge color.
    _buildGraph(treeData, null);
    builder
      ..siblingSeparation = (60)
      ..levelSeparation = (80)
      ..subtreeSeparation = (60)
      ..orientation = (BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM);
  }

  // UPDATE: Now takes parent data to style the connecting edge.
  void _buildGraph(Map<String, dynamic> nodeData, Map<String, dynamic>? parentData) {
    var node = Node.Id(nodeData['id']);
    graph.addNode(node);

    if (parentData != null) {
      var parentNode = Node.Id(parentData['id']);
      bool isParentOptimal = _isNodeOnPath(parentData);
      bool isCurrentOptimal = _isNodeOnPath(nodeData);

      // UPDATE: Set edge color based on whether it's part of the optimal path.
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
  
  // UPDATE: New helper function to check if a node is on the optimal path.
  bool _isNodeOnPath(Map<String, dynamic> nodeData) {
    List<dynamic> nodePath = nodeData['path'] ?? [];
    // The root node is always part of the path.
    if (nodePath.isEmpty) return true;
    if (nodePath.length > optimalPath.length) return false;
    // Check if the node's path is a prefix of the final optimal path.
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
    // UPDATE: Determine node style based on whether it is on the optimal path.
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