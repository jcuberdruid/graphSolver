import Foundation

struct AlphabetStruct {
    let id: String?
    let allowedMoves: [[String?]]?
    
    init(id: String? = nil, allowedMoves: [[String?]]? = nil) {
        self.id = id
        self.allowedMoves = allowedMoves
    }
}
extension AlphabetStruct: Hashable {
    static func == (lhs: AlphabetStruct, rhs: AlphabetStruct) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

protocol GameRules {
    func distance(boardState: [[AlphabetStruct]]) -> Int
    func goal(boardState: [[AlphabetStruct]]) -> Bool
}

class GameState {
    static var size: Int = 0 //sidelength
    let gameRules: GameRules
    var boardState: [[AlphabetStruct]]
    var distance: Int = 0
    
    init(gameRules: GameRules, boardState: [[AlphabetStruct]]) {
        self.boardState = boardState
        self.gameRules = gameRules
        self.calculateDistance()
    }
    func calculateDistance() {
        self.distance = self.gameRules.distance(boardState: self.boardState)
    }
    /*
    ##################################################################
    ##################################################################
    # GenerateSuccessors + helper functions
    ##################################################################
    ##################################################################
    */
    func overlayAllowedMovesOnBoard(allowedMovesMatrix: [[String?]], boardStateMatrix: [[AlphabetStruct?]], currentPieceRow: Int, currentPieceColumn: Int) -> [[String?]] {
        var modifiedAllowedMoves: [[String?]] = Array(repeating: Array(repeating: nil, count: boardStateMatrix[0].count), count: boardStateMatrix.count)

        let allowedMovesRowCount = allowedMovesMatrix.count
        let allowedMovesColumnCount = allowedMovesMatrix[0].count
        let allowedMovesRowHalf = allowedMovesRowCount / 2
        let allowedMovesColumnHalf = allowedMovesColumnCount / 2

        for rowIndex in 0..<allowedMovesRowCount {
            for colIndex in 0..<allowedMovesColumnCount {
                let boardRow = currentPieceRow - allowedMovesRowHalf + rowIndex
                let boardCol = currentPieceColumn - allowedMovesColumnHalf + colIndex

                if boardRow >= 0, boardRow < boardStateMatrix.count, boardCol >= 0, boardCol < boardStateMatrix[0].count {
                    modifiedAllowedMoves[boardRow][boardCol] = allowedMovesMatrix[rowIndex][colIndex]
                }
            }
        }

        return modifiedAllowedMoves
    }
    func isClear(targetPosition: (row: Int, column: Int), currentPosition: (row: Int, column: Int), boardState: [[AlphabetStruct?]]) -> Bool {
        if targetPosition.row != currentPosition.row &&
            targetPosition.column != currentPosition.column &&
            abs(targetPosition.row - currentPosition.row) != abs(targetPosition.column - currentPosition.column) {
            return false
        }
        let rowDirection = targetPosition.row > currentPosition.row ? 1 : (targetPosition.row < currentPosition.row ? -1 : 0)
        let columnDirection = targetPosition.column > currentPosition.column ? 1 : (targetPosition.column < currentPosition.column ? -1 : 0)
        var checkPosition = (row: currentPosition.row + rowDirection, column: currentPosition.column + columnDirection)
        while checkPosition != targetPosition {
            if boardState[checkPosition.row][checkPosition.column] != nil {
                return false
            }
            checkPosition = (row: checkPosition.row + rowDirection, column: checkPosition.column + columnDirection)
        }
        return true
    }
    func generateSuccessors() -> [GameState] {
        var movementPossibilities: [GameState] = []
        for (rowIndex, row) in self.boardState.enumerated() {
            for (columnIndex, alphabetStruct) in row.enumerated() {
                guard let allowedMoves = alphabetStruct.allowedMoves else { continue }
                let modifiedAllowedMoves = overlayAllowedMovesOnBoard(allowedMovesMatrix: allowedMoves, boardStateMatrix: self.boardState.map { $0.map { $0 } }, currentPieceRow: rowIndex, currentPieceColumn: columnIndex)
                //let modifiedAllowedMoves = overlayAllowedMovesOnBoard(allowedMovesMatrix: allowedMoves, boardStateMatrix: self.boardState, currentPieceRow: rowIndex, currentPieceColumn: columnIndex)
                for (movesRowIndex, movesRow) in modifiedAllowedMoves.enumerated() {
                    for (movesColumnIndex, allowedMove) in movesRow.enumerated() {
                        guard let allowedMove = allowedMove else { continue } // Skip if nil
                        let targetPosition = (row: movesRowIndex, column: movesColumnIndex)
                        let pathClear = isClear(targetPosition: targetPosition, currentPosition: (row: rowIndex, column: columnIndex), boardState: self.boardState)
                        var newBoardState = self.boardState // Copy of current board state
                        
                        switch allowedMove {
                        case "s",
                             "sc" where pathClear:
                            let temp = newBoardState[rowIndex][columnIndex]
                            newBoardState[rowIndex][columnIndex] = newBoardState[targetPosition.row][targetPosition.column]
                            newBoardState[targetPosition.row][targetPosition.column] = temp
                            let newGameState = GameState(gameRules: gameRules, boardState: newBoardState)
                            movementPossibilities.append(newGameState)
                            break
                        case "r",
                             "rc" where pathClear:
                            //replace piece at target position with current piece
                            newBoardState[targetPosition.row][targetPosition.column] = newBoardState[rowIndex][columnIndex]
                            newBoardState[rowIndex][columnIndex] = .init()
                            let newGameState = GameState(gameRules: gameRules, boardState: newBoardState)
                            movementPossibilities.append(newGameState)
                            break
                        case "c" where pathClear && newBoardState[targetPosition.row][targetPosition.column].id == nil:
                            //move to if path and target position is clear
                            newBoardState[targetPosition.row][targetPosition.column] = newBoardState[rowIndex][columnIndex]
                            newBoardState[rowIndex][columnIndex] = .init()
                            let newGameState = GameState(gameRules: gameRules, boardState: newBoardState)
                            movementPossibilities.append(newGameState)
                            break
                        case "f" where newBoardState[targetPosition.row][targetPosition.column].id == nil:
                            //move to target location if target position is clear
                            newBoardState[targetPosition.row][targetPosition.column] = newBoardState[rowIndex][columnIndex]
                            newBoardState[rowIndex][columnIndex] = .init()
                            let newGameState = GameState(gameRules: gameRules, boardState: newBoardState)
                            movementPossibilities.append(newGameState)
                            break
                        default:
                            break //if invalid/broken allowedMove index state
                            
                        }
                    }
                }
            }
        }
        return movementPossibilities
    }
}

struct TreeNode {
    var board: GameState
    var cost: Int
    var distance: Int
    var parent: [TreeNode] = []
    var leaves: [TreeNode] = []

    mutating func add(child: TreeNode) {
        self.leaves.append(child)
    }
    
    init(board: GameState, cost: Int, distance: Int, inputLeaves: [TreeNode]? = nil, parent: [TreeNode]? = nil) {
        self.board = board
        self.cost = cost
        self.distance = distance
        if let inputLeaves = inputLeaves {
            self.leaves = inputLeaves
        }
        if let parent = parent {
            self.parent = parent
        }
    }
}

extension TreeNode: Hashable {
    static func == (lhs: TreeNode, rhs: TreeNode) -> Bool {
        for (colIndex, lhsColumn) in lhs.board.boardState.enumerated() {
            for (rowIndex, lhsRow) in lhsColumn.enumerated() {
                if (rhs.board.boardState[colIndex][rowIndex] != lhsRow) {
                    return false
                }
            }

        }
        return true
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(board.boardState)
    }
}
/*
##################################################################
##################################################################
# n-queens
##################################################################
##################################################################
*/

struct NQueensGameRules: GameRules {
    func distance(boardState: [[AlphabetStruct]]) -> Int {
        return 0
    }
    func goal(boardState: [[AlphabetStruct]]) -> Bool {
        let rowCount = boardState.count
        let columnCount = boardState[0].count
        for row in 0..<rowCount {
            for col in 0..<columnCount {
                if boardState[row][col].id == nil {
                    continue
                }
                for otherRow in 0..<rowCount {
                    if otherRow != row && boardState[otherRow][col].id != nil {
                        return false
                    }
                }
                for otherCol in 0..<columnCount {
                    if otherCol != col && boardState[row][otherCol].id != nil {
                        return false
                    }
                }
                let diagonals = [
                    [-1, -1],
                    [1, 1],
                    [-1, 1],
                    [1, -1]
                ]
                for diagonalDistance in 1..<boardState.count {
                    for diagonal in diagonals {
                        let otherRow = row + diagonal[0] * diagonalDistance
                        let otherCol = col + diagonal[1] * diagonalDistance
                        if otherRow < 0 || otherRow >= rowCount || otherCol < 0 || otherCol >= columnCount {
                            continue
                        }
                        if boardState[otherRow][otherCol].id != nil {
                            return false
                        }
                    }
                }
            }
        }
        return true
    }
}

func nQueensInitializeBoard(size: Int) -> [[AlphabetStruct]] {
    var board: [[AlphabetStruct]] = []
    var num = 0
    for _ in 0..<size {
        var row: [AlphabetStruct] = []
        for _ in 0..<size {
            if num != 0 {
                let alphabetStruct = AlphabetStruct(id: nil, allowedMoves: nil)
                row.append(alphabetStruct)
            } else {
                let queen = AlphabetStruct(id: "Q", allowedMoves: [[nil, "s", nil], [nil, "s", nil], [nil, "s", nil]])
                row.append(queen)
            }
        }
        num = 1
        board.append(row)
    }
    return board
}


/*
##################################################################
##################################################################
# n-puzzle
##################################################################
##################################################################
*/
struct NPuzzlesGameRules: GameRules {
    func distance(boardState: [[AlphabetStruct]]) -> Int {
        var distance = 0
        var expectedValue = 1
        for row in boardState {
            for cell in row {
                if let cellValue = cell.id, let intValue = Int(cellValue), intValue != expectedValue {
                    distance += 1
                } else if cell.id == nil && expectedValue != boardState.count * boardState[0].count {
                    distance += 1
                }
                expectedValue += 1
            }
        }
        return distance
    }
    func goal(boardState: [[AlphabetStruct]]) -> Bool {
        var expectedValue = 1
        for row in boardState {
            for cell in row {
                if let cellValue = cell.id, let intValue = Int(cellValue), intValue == expectedValue {
                    expectedValue += 1
                } else if cell.id == nil && expectedValue == boardState.count * boardState[0].count {
                    return true
                } else {
                    return false
                }
            }
        }
        return expectedValue == boardState.count * boardState[0].count + 1
    }
    
}

func nPuzzleInitializeBoard(size: Int) -> [[AlphabetStruct]] {
    var board: [[AlphabetStruct]] = []
    var num = 1
    for _ in 0..<size {
        var row: [AlphabetStruct] = []
        for _ in 0..<size {
            if num < size * size {
                let alphabetStruct = AlphabetStruct(id: "\(num)", allowedMoves: nil)
                row.append(alphabetStruct)
            } else {
                let emptySpace = AlphabetStruct(id: nil, allowedMoves: [[nil, "s", nil], ["s", nil, "s"], [nil, "s", nil]])
                row.append(emptySpace)
            }
            num += 1
        }
        board.append(row)
    }
    let swapCount = size * size * 2 // sorta badly statistical method
    for _ in 0..<swapCount {
        let pos1 = (Int.random(in: 0..<size), Int.random(in: 0..<size))
        let pos2 = (Int.random(in: 0..<size), Int.random(in: 0..<size))
        let temp = board[pos1.0][pos1.1]
        board[pos1.0][pos1.1] = board[pos2.0][pos2.1]
        board[pos2.0][pos2.1] = temp
    }
    return board
}

func nPuzzleGoalNode(size: Int) -> TreeNode {
    var boardState = nPuzzleInitializeBoard(size: size)
    var expectedValue = 1
    for row in 0..<size {
        for col in 0..<size {
            if expectedValue == size * size {
                boardState[row][col] = .init(id: nil, allowedMoves: [[nil, "s", nil], ["s", nil, "s"], [nil, "s", nil]])
                continue
            }
            boardState[row][col] = .init(id: String(expectedValue))
            expectedValue += 1
        }
    }
    return TreeNode(board: GameState(gameRules: NPuzzlesGameRules(), boardState: boardState), cost: 0, distance: 0)
}

/*
##################################################################
##################################################################
# Graph Search, print,  and Main
##################################################################
##################################################################
func printBoardState(boardState: [[AlphabetStruct?]]) {
    print("#################")
    for row in boardState {
        for cell in row {
            if let cellValue = cell?.id {
                print(cellValue, terminator: " ")
            } else {
                print("_", terminator: " ") // Use "_" to represent nil (empty space)
            }
        }
        print() // Newline after each row
    }
    print("#################")
}
*/
func printBoardState(boardState: [[AlphabetStruct?]]) {
    print("#################")

    // Find the maximum length of the cell values
    let maxLength = boardState.flatMap { $0 }.compactMap { $0?.id }.max(by: { $0.count < $1.count })?.count ?? 1

    for row in boardState {
        for cell in row {
            if let cellValue = cell?.id {
                // Format the cell value to have a fixed width equal to maxLength
                let formattedValue = cellValue.padding(toLength: maxLength, withPad: " ", startingAt: 0)
                print(formattedValue, terminator: " ")
            } else {
                // Format the placeholder to have the same width as maxLength
                let placeholder = String(repeating: "_", count: maxLength)
                print(placeholder, terminator: " ")
            }
        }
        print() // Newline after each row
    }

    print("#################")
}

enum SearchType {
    case breadthFirst
    case depthFirst
    case iterativeDeepening
    case bidirectional
}

func bfs(initialNode: TreeNode) -> Bool {
    var visitedNodes = Set<TreeNode>()
    var nodeQueue: [TreeNode] = [initialNode]
    visitedNodes.insert(initialNode)
    
    while(!nodeQueue.isEmpty) {
        let node = nodeQueue.removeFirst()
        if(node.board.gameRules.goal(boardState: node.board.boardState)) {
            print("Found solution, cost \(node.cost)")
            printBoardState(boardState: node.board.boardState)
            return true
        }
        let nextStates = node.board.generateSuccessors()
        for state in nextStates {
            state.calculateDistance()
            let newNode = TreeNode(board: state, cost: node.cost+1, distance: state.distance)
            if !visitedNodes.contains(newNode) {
                nodeQueue.append(newNode)
                visitedNodes.insert(newNode)
            }
        }
    }
    
    return false
}

func dfs(initialNode: TreeNode) -> Bool {
    var visitedNodes = Set<TreeNode>()
    var nodeStack = [initialNode]
    
    while(!nodeStack.isEmpty) {
        let node = nodeStack.removeLast()
        let nextStates = node.board.generateSuccessors()
        if node.board.gameRules.goal(boardState: node.board.boardState) {
            print("Found solution, cost \(node.cost)")
            printBoardState(boardState: node.board.boardState)
            return true
        }
        visitedNodes.insert(node)
        for state in nextStates {
            state.calculateDistance()
            let newNode = TreeNode(board: state, cost: node.cost+1, distance: state.distance)
            if !visitedNodes.contains(newNode) {
//                printBoardState(boardState: newNode.board.boardState)
                nodeStack.append(newNode)
            }
        }
    }
    
    return false
}

func ids(initialNode: TreeNode) -> Bool {
    var visitedAllAvailableNodes = false
    var targetDepth = 1
    while(!visitedAllAvailableNodes) {
        var nodeStack = [initialNode]
        visitedAllAvailableNodes = true
        
        var visitedNodes = Set<TreeNode>()
        while(!nodeStack.isEmpty) {
            let node = nodeStack.removeLast()
            let nextStates = node.board.generateSuccessors()
            
            visitedNodes.insert(node)
            
            if node.cost == targetDepth {
                if node.board.gameRules.goal(boardState: node.board.boardState) {
                    print("Found solution, cost \(node.cost)")
                    printBoardState(boardState: node.board.boardState)
                    return true
                }
                continue
            }
            
            for state in nextStates {
                state.calculateDistance()
                let newNode = TreeNode(board: state, cost: node.cost+1, distance: state.distance)
                if !visitedNodes.contains(newNode) {
                    visitedAllAvailableNodes = false
                    nodeStack.append(newNode)
                }
            }
        }
        targetDepth += 1
    }
    
    return false
}

func bds(initialNode: TreeNode, goalNode: TreeNode) -> Bool {
    var visitedFromInitialNode: Set<TreeNode> = [initialNode]
    var visitedFromGoalNode: Set<TreeNode> = [goalNode]
    
    var queueFromInitialNode = [initialNode]
    var queueFromGoalNode = [goalNode]
    
    while !queueFromInitialNode.isEmpty && !queueFromGoalNode.isEmpty {
        let node1 = queueFromInitialNode.removeFirst()
        if visitedFromGoalNode.contains(node1) {
            print("Found solution, cost of first intersecting node \(node1.cost)")
            return true
        }
        let nextStates1 = node1.board.generateSuccessors()
        for state in nextStates1 {
            state.calculateDistance()
            let newNode = TreeNode(board: state, cost: node1.cost+1, distance: state.distance)
            if !visitedFromInitialNode.contains(newNode) {
                queueFromInitialNode.append(newNode)
                visitedFromInitialNode.insert(newNode)
            }
        }
        
        let node2 = queueFromGoalNode.removeFirst()
        if visitedFromInitialNode.contains(node2) {
            print("Found solution, cost of first intersecting node \(node2.cost)")
            return true
        }
        let nextStates2 = node2.board.generateSuccessors()
        for state in nextStates2 {
            state.calculateDistance()
            let newNode = TreeNode(board: state, cost: node2.cost+1, distance: state.distance)
            if !visitedFromGoalNode.contains(newNode) {
                queueFromGoalNode.append(newNode)
                visitedFromGoalNode.insert(newNode)
            }
        }
    }
    
    return false
}

func graphSearch(initialNode: TreeNode, goalNode: TreeNode? = nil, searchType: SearchType) {
    print("Starting search of type \(searchType), initial board state:")
    printBoardState(boardState: initialNode.board.boardState)
    
    switch searchType {
    case .breadthFirst:
        if !bfs(initialNode: initialNode) {
            print("No solution found")
        }
    case .depthFirst:
        if !dfs(initialNode: initialNode) {
            print("No solution found")
        }
    case .iterativeDeepening:
        if !ids(initialNode: initialNode) {
            print("No solution found")
        }
    case .bidirectional:
        guard let goalNode = goalNode else {
            print("Goal node is required for bidirectional search")
            return
        }
        if !bds(initialNode: initialNode, goalNode: goalNode) {
            print("No solution found")
        }
    }
}

func main1() {
    //npuzzle setup
    GameState.size = 3
    let initialBoardState = nPuzzleInitializeBoard(size: GameState.size)
    let initialGameState = GameState(gameRules: NPuzzlesGameRules(), boardState: initialBoardState)
    initialGameState.calculateDistance()
    
    //initial Treenode:
    let initialNode = TreeNode(board: initialGameState, cost: 0, distance: initialGameState.distance)
    let goalNode = nPuzzleGoalNode(size: GameState.size)

    graphSearch(initialNode: initialNode, goalNode: goalNode, searchType: .bidirectional)
}

func writeToCsv(fileName: String, line: String) {
    print(fileName)
    if !FileManager.default.fileExists(atPath: fileName) {
        FileManager.default.createFile(atPath: fileName, contents: nil)
    }

    if let fileHandle = FileHandle(forWritingAtPath: fileName) {
        defer {
            fileHandle.closeFile()
        }
        fileHandle.seekToEndOfFile()
        if let data = line.data(using: .utf8) {
            fileHandle.write(data)
        }
    } else {
        exit(1)
    }
}


func main() {
    
    let searchTypeArrayNQueens: [SearchType] = [.depthFirst] 
    let fileName = "graphSearchResultsPuzzle.csv"
    //let csvHeader = "problem,n,searchType,timeTaken\n"
   
    /* 
    writeToCsv(fileName: fileName, line: csvHeader)
    for chosenSearchType in searchTypeArrayNQueens {
        for n in 7...10 {
            for _ in 1...3 {
                let startTime = Date()
                
                GameState.size = n
                let initialBoardState = nQueensInitializeBoard(size: GameState.size)
                let initialGameState = GameState(gameRules: NQueensGameRules(), boardState: initialBoardState)
                let initialNode = TreeNode(board: initialGameState, cost: 0, distance: initialGameState.distance)
                graphSearch(initialNode: initialNode, searchType: chosenSearchType)
                
                let endTime = Date()
                let timeInterval = endTime.timeIntervalSince(startTime)
                
                let csv_row = "nqueens,\(n),\(chosenSearchType),\(timeInterval)\n"
                
    		writeToCsv(fileName: fileName, line: csv_row)
                
            }
        }
    }
    */
    for chosenSearchType in searchTypeArrayNQueens {
        for n in 3...6 {
            for _ in 1...3 {
                let startTime = Date()

		    //npuzzle setup
                    GameState.size = n
		    let initialBoardState = nPuzzleInitializeBoard(size: GameState.size)
		    let initialGameState = GameState(gameRules: NPuzzlesGameRules(), boardState: initialBoardState)
		    initialGameState.calculateDistance()
		    
		    //initial Treenode:
		    let initialNode = TreeNode(board: initialGameState, cost: 0, distance: initialGameState.distance)
		    if chosenSearchType == .bidirectional {
			let goalNode = nPuzzleGoalNode(size: GameState.size)
		    	graphSearch(initialNode: initialNode, goalNode: goalNode, searchType: chosenSearchType)
		    } else {
		    	graphSearch(initialNode: initialNode, searchType: chosenSearchType)
		    }

                let endTime = Date()
                let timeInterval = endTime.timeIntervalSince(startTime)

                let csv_row = "npuzzle,\(n),\(chosenSearchType),\(timeInterval)\n"

                writeToCsv(fileName: fileName, line: csv_row)

            }
        }
    }

}
main()
