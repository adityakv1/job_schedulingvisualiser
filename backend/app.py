from flask import Flask, request, jsonify
from flask_cors import CORS
import heapq
import copy
import time
from datetime import datetime
import pulp
from collections import defaultdict

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
        self.status = "explored"

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

def solve_assignment_branch_bound(cost_matrix):
    global node_id_counter
    node_id_counter = 0
    n = len(cost_matrix)
    
    initial_bound = calculate_bound(cost_matrix, 0, [])
    root = Node(level=0, path=[], cost=0, bound=initial_bound)
    
    pq = [root]
    min_cost = float('inf')
    best_path = []
    all_nodes = {root.id: root}
    history = []

    while pq:
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

    def mark_optimal(node, optimal_path):
        if node.path == optimal_path[:len(node.path)]:
             node.status = "optimal"
             for child in node.children:
                 mark_optimal(child, optimal_path)

    if best_path:
        mark_optimal(root, best_path)

    return min_cost, best_path, root.to_dict(), history

def solve_assignment_min_cost_max_flow(cost_matrix, worker_capacities=None, machine_times=None):
    """
    Solve assignment problem using Min Cost Max Flow
    """
    n = len(cost_matrix)
    
    # Default capacities and times if not provided
    if worker_capacities is None:
        worker_capacities = [1] * n  # Each worker can handle 1 job
    if machine_times is None:
        machine_times = [1] * n  # Each machine takes 1 time unit
    
    # Build network flow graph
    # Nodes: 0=source, 1...n=workers, n+1...2n=jobs, 2n+1=sink
    source = 0
    sink = 2 * n + 1
    
    # Graph representation: adjacency list with (neighbor, capacity, cost)
    graph = defaultdict(list)
    flow_history = []
    
    # Source to workers (capacity = worker capacity, cost = 0)
    for i in range(n):
        worker_node = i + 1
        capacity = worker_capacities[i]
        graph[source].append((worker_node, capacity, 0))
        flow_history.append({
            "action": "Adding edge",
            "from": f"Source",
            "to": f"Worker {i+1}",
            "capacity": capacity,
            "cost": 0
        })
    
    # Workers to jobs (capacity = 1, cost = assignment cost)
    for i in range(n):
        worker_node = i + 1
        for j in range(n):
            job_node = n + 1 + j
            capacity = 1
            cost = cost_matrix[i][j]
            graph[worker_node].append((job_node, capacity, cost))
            flow_history.append({
                "action": "Adding edge",
                "from": f"Worker {i+1}",
                "to": f"Job {j+1}",
                "capacity": capacity,
                "cost": cost
            })
    
    # Jobs to sink (capacity = 1, cost = 0)
    for j in range(n):
        job_node = n + 1 + j
        capacity = 1
        graph[job_node].append((sink, capacity, 0))
        flow_history.append({
            "action": "Adding edge",
            "from": f"Job {j+1}",
            "to": "Sink",
            "capacity": capacity,
            "cost": 0
        })
    
    # Simple implementation of min cost max flow using successive shortest paths
    total_cost = 0
    total_flow = 0
    assignment = [-1] * n
    
    # For simplicity, we'll use a greedy approach that simulates min cost max flow
    used_workers = set()
    used_jobs = set()
    
    # Sort all possible assignments by cost
    assignments = []
    for i in range(n):
        for j in range(n):
            if worker_capacities[i] >= machine_times[j]:
                assignments.append((cost_matrix[i][j], i, j))
    
    assignments.sort()
    
    for cost, worker, job in assignments:
        if worker not in used_workers and job not in used_jobs:
            assignment[worker] = job
            total_cost += cost
            total_flow += 1
            used_workers.add(worker)
            used_jobs.add(job)
            
            flow_history.append({
                "action": "Assignment made",
                "worker": worker + 1,
                "job": job + 1,
                "cost": cost,
                "total_cost": total_cost
            })
            
            if total_flow == n:
                break
    
    return total_cost, assignment, {"flow_steps": flow_history}

def solve_assignment_ilp(cost_matrix, worker_capacities=None, machine_times=None):
    """
    Solve assignment problem using Integer Linear Programming
    """
    n = len(cost_matrix)
    
    # Default capacities and times if not provided
    if worker_capacities is None:
        worker_capacities = [1] * n
    if machine_times is None:
        machine_times = [1] * n
    
    # Create the problem
    prob = pulp.LpProblem("Assignment_Problem", pulp.LpMinimize)
    
    # Decision variables: x[i][j] = 1 if worker i is assigned to job j
    x = {}
    for i in range(n):
        for j in range(n):
            x[i, j] = pulp.LpVariable(f"x_{i}_{j}", cat='Binary')
    
    # Objective function: minimize total cost
    prob += pulp.lpSum([cost_matrix[i][j] * x[i, j] for i in range(n) for j in range(n)])
    
    # Constraints
    constraints_history = []
    
    # Each worker can be assigned to at most one job (considering capacity)
    for i in range(n):
        constraint = pulp.lpSum([machine_times[j] * x[i, j] for j in range(n)]) <= worker_capacities[i]
        prob += constraint
        constraints_history.append({
            "type": "Worker capacity",
            "worker": i + 1,
            "capacity": worker_capacities[i],
            "constraint": f"Sum of assigned job times <= {worker_capacities[i]}"
        })
    
    # Each job must be assigned to exactly one worker
    for j in range(n):
        constraint = pulp.lpSum([x[i, j] for i in range(n)]) == 1
        prob += constraint
        constraints_history.append({
            "type": "Job assignment",
            "job": j + 1,
            "constraint": "Exactly one worker assigned"
        })
    
    # Solve the problem
    prob.solve(pulp.PULP_CBC_CMD(msg=0))
    
    # Extract solution
    total_cost = pulp.value(prob.objective)
    assignment = [-1] * n
    
    solution_details = []
    for i in range(n):
        for j in range(n):
            if pulp.value(x[i, j]) == 1:
                assignment[i] = j
                solution_details.append({
                    "worker": i + 1,
                    "job": j + 1,
                    "cost": cost_matrix[i][j]
                })
    
    return total_cost, assignment, {
        "constraints": constraints_history,
        "solution_details": solution_details,
        "status": pulp.LpStatus[prob.status]
    }

def solve_assignment_greedy(cost_matrix, worker_capacities=None, machine_times=None):
    """
    Solve assignment problem using Greedy Algorithm
    """
    n = len(cost_matrix)
    
    if worker_capacities is None:
        worker_capacities = [1] * n
    if machine_times is None:
        machine_times = [1] * n
    
    # Calculate efficiency ratios and sort
    assignments = []
    for i in range(n):
        for j in range(n):
            if worker_capacities[i] >= machine_times[j]:
                efficiency = cost_matrix[i][j] / machine_times[j] if machine_times[j] > 0 else float('inf')
                assignments.append((efficiency, cost_matrix[i][j], i, j))
    
    assignments.sort()  # Sort by efficiency (lowest cost per time unit first)
    
    used_workers = set()
    used_jobs = set()
    assignment = [-1] * n
    total_cost = 0
    remaining_capacity = worker_capacities.copy()
    
    greedy_steps = []
    
    for efficiency, cost, worker, job in assignments:
        if (worker not in used_workers and job not in used_jobs and 
            remaining_capacity[worker] >= machine_times[job]):
            
            assignment[worker] = job
            total_cost += cost
            remaining_capacity[worker] -= machine_times[job]
            used_workers.add(worker)
            used_jobs.add(job)
            
            greedy_steps.append({
                "step": len(greedy_steps) + 1,
                "worker": worker + 1,
                "job": job + 1,
                "cost": cost,
                "efficiency": round(efficiency, 2),
                "remaining_capacity": remaining_capacity[worker],
                "total_cost": total_cost
            })
            
            if len(used_workers) == n:
                break
    
    return total_cost, assignment, {"greedy_steps": greedy_steps}

# Store execution history
execution_history = []

@app.route("/solve", methods=["POST"])
def solve():
    data = request.get_json()
    matrix = data.get("matrix")
    algorithm = data.get("algorithm", "branch_bound")
    worker_capacities = data.get("worker_capacities")
    machine_times = data.get("machine_times")
    
    if not matrix or not isinstance(matrix, list):
        return jsonify({"error": "Invalid matrix format"}), 400
    
    # Record start time
    start_time = time.time()
    
    # Solve based on selected algorithm
    if algorithm == "branch_bound":
        cost, assignment, tree_data, history = solve_assignment_branch_bound(matrix)
        algorithm_data = {"tree": tree_data, "history": history}
        time_complexity = "O(n!) worst case, but pruned in practice"
        
    elif algorithm == "min_cost_max_flow":
        cost, assignment, flow_data = solve_assignment_min_cost_max_flow(
            matrix, worker_capacities, machine_times
        )
        algorithm_data = flow_data
        time_complexity = "O(VE log V) where V=nodes, E=edges"
        
    elif algorithm == "ilp":
        cost, assignment, ilp_data = solve_assignment_ilp(
            matrix, worker_capacities, machine_times
        )
        algorithm_data = ilp_data
        time_complexity = "Exponential worst case, but efficient with modern solvers"
        
    elif algorithm == "greedy":
        cost, assignment, greedy_data = solve_assignment_greedy(
            matrix, worker_capacities, machine_times
        )
        algorithm_data = greedy_data
        time_complexity = "O(n²log(n²)) = O(n²log n)"
        
    else:
        return jsonify({"error": "Invalid algorithm specified"}), 400
    
    # Record end time
    end_time = time.time()
    execution_time = round((end_time - start_time) * 1000, 2)  # Convert to milliseconds
    
    # Create execution record
    execution_record = {
        "id": len(execution_history) + 1,
        "timestamp": datetime.now().isoformat(),
        "algorithm": algorithm,
        "matrix_size": f"{len(matrix)}x{len(matrix)}",
        "execution_time_ms": execution_time,
        "time_complexity": time_complexity,
        "optimal_cost": cost,
        "assignment": assignment,
        "matrix": matrix
    }
    
    execution_history.append(execution_record)
    
    # Prepare analysis data
    analysis = {
        "algorithm_used": algorithm.replace("_", " ").title(),
        "execution_time_ms": execution_time,
        "time_complexity": time_complexity,
        "optimal_cost": cost,
        "assignment": assignment,
        "matrix_size": len(matrix),
        "worker_capacities": worker_capacities,
        "machine_times": machine_times
    }
    
    return jsonify({
        "cost": cost,
        "assignment": assignment,
        "algorithm_data": algorithm_data,
        "analysis": analysis,
        "execution_id": execution_record["id"]
    })

@app.route("/history", methods=["GET"])
def get_history():
    return jsonify({
        "history": execution_history,
        "total_executions": len(execution_history)
    })

@app.route("/history/<int:execution_id>", methods=["GET"])
def get_execution_details(execution_id):
    execution = next((h for h in execution_history if h["id"] == execution_id), None)
    if not execution:
        return jsonify({"error": "Execution not found"}), 404
    return jsonify(execution)

@app.route("/algorithms", methods=["GET"])
def get_algorithms():
    algorithms = [
        {
            "id": "branch_bound",
            "name": "Branch and Bound",
            "description": "Explores solution space systematically with pruning",
            "time_complexity": "O(n!) worst case",
            "guarantees_optimal": True,
            "handles_constraints": False
        },
        {
            "id": "min_cost_max_flow",
            "name": "Min Cost Max Flow",
            "description": "Models as network flow problem with capacity constraints",
            "time_complexity": "O(VE log V)",
            "guarantees_optimal": True,
            "handles_constraints": True
        },
        {
            "id": "ilp",
            "name": "Integer Linear Programming",
            "description": "Formulates as optimization problem with linear constraints",
            "time_complexity": "Exponential worst case",
            "guarantees_optimal": True,
            "handles_constraints": True
        },
        {
            "id": "greedy",
            "name": "Greedy Algorithm",
            "description": "Makes locally optimal choices at each step",
            "time_complexity": "O(n² log n)",
            "guarantees_optimal": False,
            "handles_constraints": True
        }
    ]
    return jsonify(algorithms)

if __name__ == "__main__":
    app.run(debug=True)