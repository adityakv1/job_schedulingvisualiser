from flask import Flask, request, jsonify
from flask_cors import CORS
import heapq
import copy

app = Flask(__name__)
CORS(app)

node_id_counter = 0

class Node:
    def __init__(self, level, path, cost, bound, parent_id=None):
        global node_id_counter
        self.id = node_id_counter
        node_id_counter += 1
        self.level = level
        self.path = path
        self.cost = cost
        self.bound = bound
        self.parent_id = parent_id
        self.children = []
        # NEW: Status to track node state for visualization
        self.status = "explored" # Can be 'explored', 'optimal', or 'pruned'

    def __lt__(self, other):
        return self.bound < other.bound

    def to_dict(self):
        return {
            "id": self.id,
            "level": self.level,
            "path": self.path,
            "cost": self.cost,
            "bound": round(self.bound, 2),
            "parent_id": self.parent_id,
            "status": self.status,
            "children": [child.to_dict() for child in self.children]
        }

def calculate_bound(cost_matrix, level, path):
    n = len(cost_matrix)
    bound = 0
    assigned_jobs = set(path)
    for i in range(level):
        if i < len(path):
            bound += cost_matrix[i][path[i]]

    for i in range(level, n):
        min_cost = float('inf')
        for j in range(n):
            if j not in assigned_jobs:
                min_cost = min(min_cost, cost_matrix[i][j])
        bound += min_cost if min_cost != float('inf') else 0
    return bound

def solve_assignment(cost_matrix):
    global node_id_counter
    node_id_counter = 0
    n = len(cost_matrix)
    
    initial_bound = calculate_bound(cost_matrix, 0, [])
    root = Node(level=0, path=[], cost=0, bound=initial_bound)
    
    pq = [root]
    min_cost = float('inf')
    best_path = []
    all_nodes = {root.id: root}
    
    # NEW: History to track each step of the algorithm
    history = []

    while pq:
        # Sort to simulate priority queue (min-heap)
        pq.sort(key=lambda x: x.bound)
        current = pq.pop(0)

        step_info = {
            "action": "Selecting Node",
            "node_id": current.id,
            "node_path": current.path,
            "node_cost": current.cost,
            "node_bound": current.bound,
            "min_cost": min_cost if min_cost != float('inf') else "inf",
            "pq_size": len(pq),
            "pq_bounds": [round(n.bound, 2) for n in pq]
        }
        
        if current.bound >= min_cost:
            current.status = "pruned"
            step_info["action"] = "Pruning Node"
            history.append(step_info)
            continue
        
        history.append(step_info)

        if current.level == n:
            if current.cost < min_cost:
                min_cost = current.cost
                best_path = current.path
                history.append({
                    "action": "New Solution Found",
                    "new_min_cost": min_cost,
                    "path": best_path
                })
            continue

        level = current.level
        for job in range(n):
            if job not in current.path:
                new_path = current.path + [job]
                new_cost = current.cost + cost_matrix[level][job]
                
                child_node = Node(
                    level=level + 1,
                    path=new_path,
                    cost=new_cost,
                    bound=0,
                    parent_id=current.id
                )
                
                new_bound = calculate_bound(cost_matrix, 0, new_path)
                child_node.bound = new_bound

                all_nodes[child_node.id] = child_node
                current.children.append(child_node)

                history.append({
                    "action": "Generating Child",
                    "parent_id": current.id,
                    "child_id": child_node.id,
                    "child_path": child_node.path,
                    "child_cost": new_cost,
                    "child_bound": new_bound,
                })
                
                if new_bound < min_cost:
                    pq.append(child_node)
                else:
                    child_node.status = "pruned"
                    history.append({
                        "action": "Pruning Child",
                        "child_id": child_node.id,
                        "reason": f"Bound ({new_bound}) >= MinCost ({min_cost})"
                    })

    # Mark the optimal path
    def mark_optimal(node, optimal_path):
        if node.path == optimal_path[:len(node.path)]:
             node.status = "optimal"
             for child in node.children:
                 mark_optimal(child, optimal_path)

    if best_path:
        mark_optimal(root, best_path)


    return min_cost, best_path, root.to_dict(), history

@app.route("/solve", methods=["POST"])
def solve():
    data = request.get_json()
    matrix = data.get("matrix")
    if not matrix or not isinstance(matrix, list):
        return jsonify({"error": "Invalid matrix format"}), 400

    cost, assignment, tree, history = solve_assignment(matrix)
    
    return jsonify({
        "cost": cost,
        "assignment": assignment,
        "tree": tree,
        "history": history,
    })

if __name__ == "__main__":
    app.run(debug=True)

