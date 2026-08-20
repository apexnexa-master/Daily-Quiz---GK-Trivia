def check_grid(name, grid, expected_colors):
    rows = len(grid)
    cols = len(grid[0])
    print(f"\n{'='*60}")
    print(f"{name} ({rows}x{cols}, {expected_colors} colors)")
    print(f"{'='*60}")
    
    all_valid = True
    
    # 1. Check no 2x2 block of same color
    for r in range(rows - 1):
        for c in range(cols - 1):
            if grid[r][c] == grid[r][c+1] == grid[r+1][c] == grid[r+1][c+1]:
                print(f"  FAIL Rule 1: 2x2 block of color {grid[r][c]} at ({r},{c})-({r+1},{c+1})")
                all_valid = False
    
    # 2 & 3. Check connectivity per color
    colors = set()
    for r in range(rows):
        for c in range(cols):
            colors.add(grid[r][c])
    
    for color in sorted(colors):
        cells = []
        for r in range(rows):
            for c in range(cols):
                if grid[r][c] == color:
                    cells.append((r, c))
        
        # Find neighbors within same color
        degree = {}
        for (r, c) in cells:
            deg = 0
            for (dr, dc) in [(-1,0),(1,0),(0,-1),(0,1)]:
                nr, nc = r+dr, c+dc
                if 0 <= nr < rows and 0 <= nc < cols and grid[nr][nc] == color:
                    deg += 1
            degree[(r, c)] = deg
        
        # Check Rule 3: no isolated cells
        for (r, c), d in degree.items():
            if d == 0:
                print(f"  FAIL Rule 3: Color {color} has isolated cell at ({r},{c})")
                all_valid = False
        
        # Check Rule 2: exactly 2 endpoints (degree 1), rest degree 2
        endpoints = sum(1 for d in degree.values() if d == 1)
        midpoints = sum(1 for d in degree.values() if d == 2)
        corners = sum(1 for d in degree.values() if d == 3)
        others = sum(1 for d in degree.values() if d > 3 or d == 0)
        
        if endpoints != 2:
            print(f"  FAIL Rule 2: Color {color} has {endpoints} endpoints (need exactly 2)")
            all_valid = False
        if corners > 0 or others > 0:
            print(f"  FAIL Rule 2: Color {color} has {corners} degree-3 and {others} degree-0/3+ cells (all non-endpoints must be degree 2)")
            all_valid = False
        
        # Also check the color is connected (simple path)
        # BFS from first cell
        visited = set()
        queue = [cells[0]]
        visited.add(cells[0])
        while queue:
            r, c = queue.pop(0)
            for (dr, dc) in [(-1,0),(1,0),(0,-1),(0,1)]:
                nr, nc = r+dr, c+dc
                if (nr, nc) in degree and (nr, nc) not in visited:
                    visited.add((nr, nc))
                    queue.append((nr, nc))
        if len(visited) != len(cells):
            print(f"  FAIL Rule 2: Color {color} is disconnected ({len(visited)}/{len(cells)} reachable)")
            all_valid = False
        
        print(f"  Color {color}: {len(cells)} cells, {endpoints} endpoints, {midpoints} midpoints -> {'OK' if endpoints==2 and midpoints==len(cells)-2 else 'BAD'}")
    
    if all_valid:
        print(f"  >>> VALID <<<")
    else:
        print(f"  >>> INVALID <<<")
    return all_valid

# Grid 1
grid1 = [
    [0, 0, 0, 1, 1],
    [0, 2, 2, 1, 1],
    [0, 2, 0, 0, 1],
    [0, 2, 0, 1, 1],
    [0, 0, 0, 1, 1],
]

# Grid 2
grid2 = [
    [0, 0, 0, 0, 0],
    [1, 1, 1, 1, 0],
    [2, 2, 2, 1, 0],
    [3, 3, 2, 1, 0],
    [3, 3, 2, 1, 0],
]

# Grid 3
grid3 = [
    [0, 0, 0, 1, 1],
    [0, 3, 3, 1, 2],
    [0, 3, 4, 1, 2],
    [0, 3, 4, 1, 2],
    [0, 4, 4, 2, 2],
]

# Grid 4
grid4 = [
    [0, 0, 0, 0, 0, 0],
    [0, 1, 1, 1, 1, 0],
    [0, 1, 2, 2, 1, 0],
    [0, 1, 2, 3, 1, 0],
    [0, 1, 2, 3, 4, 0],
    [0, 1, 2, 3, 4, 0],
]

# Grid 5
grid5 = [
    [0, 0, 0, 1, 2, 2],
    [0, 3, 3, 1, 2, 4],
    [0, 3, 5, 1, 2, 4],
    [0, 3, 5, 1, 2, 4],
    [0, 3, 5, 1, 2, 4],
    [0, 3, 5, 1, 2, 4],
]

# Grid 6
grid6 = [
    [0, 0, 0, 0, 0, 0, 0],
    [0, 1, 1, 1, 1, 1, 0],
    [0, 1, 2, 2, 2, 1, 0],
    [0, 1, 2, 3, 2, 1, 0],
    [0, 1, 2, 3, 4, 1, 0],
    [0, 1, 2, 3, 5, 1, 0],
    [0, 1, 2, 3, 5, 1, 0],
]

# Grid 7
grid7 = [
    [0, 0, 0, 0, 0, 0, 0],
    [0, 1, 1, 1, 1, 1, 1],
    [0, 1, 2, 2, 2, 2, 2],
    [0, 1, 2, 3, 3, 3, 3],
    [0, 1, 2, 3, 4, 4, 4],
    [0, 1, 2, 3, 4, 5, 6],
    [0, 1, 2, 3, 4, 5, 6],
]

# Grid 8
grid8 = [
    [0, 0, 0, 0, 0, 0, 0, 0],
    [0, 1, 1, 1, 1, 1, 1, 0],
    [0, 1, 2, 2, 2, 2, 1, 0],
    [0, 1, 2, 3, 3, 2, 1, 0],
    [0, 1, 2, 3, 4, 2, 1, 0],
    [0, 1, 2, 3, 5, 2, 1, 0],
    [0, 1, 2, 3, 6, 2, 1, 0],
    [0, 1, 2, 3, 6, 2, 1, 0],
]

check_grid("Grid 1", grid1, 3)
check_grid("Grid 2", grid2, 4)
check_grid("Grid 3", grid3, 5)
check_grid("Grid 4", grid4, 5)
check_grid("Grid 5", grid5, 6)
check_grid("Grid 6", grid6, 6)
check_grid("Grid 7", grid7, 7)
check_grid("Grid 8", grid8, 7)
