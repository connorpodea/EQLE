import SwiftUI

// MARK: - Toast Modifier
// Custom view modifier for showing toast notifications
struct Toast: ViewModifier {
    @Binding var message: String    // Text to display in toast
    @Binding var isShowing: Bool    // Controls toast visibility
    
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content  // The main content over which toast will appear
            
            if isShowing {
                VStack {
                    Text(message)
                        .cornerRadius(20)
                        .padding()
                        // Gradient background for toast
                        .background(LinearGradient(gradient: Gradient(colors: [.pink, .purple]),
                                                   startPoint: .leading,
                                                   endPoint: .trailing))
                        .foregroundColor(.white)
                        .font(.headline)
                        .cornerRadius(10)
                        // Slide-down animation with fade
                        .transition(AnyTransition.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            // Auto-dismiss after 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    isShowing = false
                                }
                            }
                        }
                    Spacer()
                }
                .padding(.top, 60)  // Position from top of screen
                .zIndex(1)  // Ensure toast appears above other content
            }
        }
    }
}

// View extension for convenient toast usage
extension View {
    func toast(message: Binding<String>, isShowing: Binding<Bool>) -> some View {
        self.modifier(Toast(message: message, isShowing: isShowing))
    }
}

// MARK: - Data Models

// Tile color states for game feedback
enum TileColor: String, Codable {
    case green, yellow, red, unset  // Color states for equation tiles
}

// Represents a single guess in the game
struct Guess: Codable {
    var equation: String           // The guessed equation string
    var tileColors: [TileColor]    // Color states for each character position
    
    init() {
        equation = String(repeating: " ", count: 8)  // Initialize empty equation
        tileColors = Array(repeating: .unset, count: 8)  // All tiles start unset
    }
}

// MARK: - Tile View with Flip Animation

// Visual representation of a single character tile with flip animation
struct TileView: View {
    let character: String   // Character to display
    let color: TileColor    // Current color state
    let shouldAnimate: Bool // Whether to trigger animation
    let delay: Double       // Animation delay for sequential effect
    
    @State private var isFlipped = false  // Controls flip animation state

    init(character: String, color: TileColor, shouldAnimate: Bool, delay: Double) {
        self.character = character
        self.color = color
        self.shouldAnimate = shouldAnimate
        self.delay = delay
        // Initialize flipped state based on color status
        _isFlipped = State(initialValue: color != .unset)
    }
    
    var body: some View {
        ZStack {
            // Front face (unflipped) - shown before animation
            if !isFlipped {
                Text(character)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .frame(width: 35, height: 35)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.gray.opacity(0.4), lineWidth: 1)
                    )
            }
            
            // Back face (flipped) - shown after animation
            if isFlipped {
                Text(character)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .frame(width: 35, height: 35)
                    .background(colorForTile(color))  // Color-coded background
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.gray.opacity(0.4), lineWidth: 1)
                    )
                    // Counter-rotate text for proper orientation
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
        }
        // 3D flip animation effect
        .rotation3DEffect(
            .degrees(isFlipped ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
        .onChange(of: shouldAnimate) { newValue in
            // Trigger animation sequence
            if newValue && !isFlipped {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isFlipped = true
                    }
                }
            }
        }
    }
    
    // Helper to map TileColor to actual Color
    private func colorForTile(_ tileColor: TileColor) -> Color {
        switch tileColor {
        case .green: return .green
        case .yellow: return .yellow
        case .red: return .red
        case .unset: return .gray.opacity(0.2)
        }
    }
}

// MARK: - Game State Logic

// Central game state management
class GameState: ObservableObject {
    // Game data properties
    @Published var answer: String = ""  // The correct equation
    @Published var guesses = [Guess](repeating: Guess(), count: 6)  // All guesses
    @Published var currentGuessIndex = 0  // Current active guess row
    @Published var currentCharIndex = 0   // Current character position in guess
    @Published var lastPlayedDate: Date?  // Last play timestamp
    @Published var showEndScreen = false  // End game modal visibility
    @Published var currentStreak = 0      // Current win streak
    @Published var bestStreak = 0         // Best streak record
    @Published var fewestTries: Int = 6   // Minimum tries for win
    @Published var nextPuzzleDate: Date?  // Next puzzle availability
    @Published var keyColors: [String: TileColor] = [:]  // Keyboard key colors
    
    // Animation state
    @Published var shouldAnimateRow: Int? = nil  // Row index to animate
    
    // Toast properties
    @Published var showToast = false     // Toast visibility
    @Published var toastMessage = ""     // Toast text content
    
    // Stats properties with automatic persistence
    @Published var totalGamesPlayed: Int = 0 {
        didSet { UserDefaults.standard.set(totalGamesPlayed, forKey: totalGamesPlayedKey) }
    }
    @Published var totalGamesWon: Int = 0 {
        didSet { UserDefaults.standard.set(totalGamesWon, forKey: totalGamesWonKey) }
    }
    @Published var winDistribution: [Int] = Array(repeating: 0, count: 6) {
        didSet { UserDefaults.standard.set(winDistribution, forKey: winDistributionKey) }
    }
    
    // Constants
    private let equationLength = 8    // Characters per equation
    private let maxGuesses = 6        // Maximum allowed guesses
    private let fewestTriesKey = "FewestTries"
    private let totalGamesPlayedKey = "TotalGamesPlayed"
    private let totalGamesWonKey = "TotalGamesWon"
    private let winDistributionKey = "WinDistribution"
    private let lastStatsUpdateKey = "LastStatsUpdate" // Flag for stats update
    private let lastGameCompletedKey = "LastGameCompletedDate" // Flag for game completion
    
    // Computed properties
    var isGameOver: Bool {
        currentGuessIndex >= maxGuesses || isSolved
    }
    
    var isSolved: Bool {
        guard currentGuessIndex > 0 else { return false }
        // Check if all tiles are green in last guess
        return guesses[currentGuessIndex - 1].tileColors.allSatisfy { $0 == .green }
    }
    
    // Check if a game can be played today
    var canPlayToday: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        if let lastCompleted = UserDefaults.standard.object(forKey: lastGameCompletedKey) as? Date,
           Calendar.current.isDate(lastCompleted, inSameDayAs: today) {
            return false // Game already played today
        }
        return true
    }
    
    init() {
        // Load persistent stats first
        loadPersistentStats()
        
        setupDailyGame()          // Initialize daily puzzle
        generateComplexEquation() // Generate solution
        
        resetDailyGameState()     // Reset daily progress
        loadGameState()           // Load saved state
        loadStreakData()          // Load streak records
    }
    
    // Load persistent stats from UserDefaults
    private func loadPersistentStats() {
        let defaults = UserDefaults.standard
        totalGamesPlayed = defaults.integer(forKey: totalGamesPlayedKey)
        totalGamesWon = defaults.integer(forKey: totalGamesWonKey)
        winDistribution = defaults.array(forKey: winDistributionKey) as? [Int] ?? Array(repeating: 0, count: 6)
        fewestTries = defaults.integer(forKey: fewestTriesKey)
        if fewestTries == 0 {
            fewestTries = 6  // Default to max tries if no wins
        }
    }
    
    // MARK: - Daily Game Setup
    private func setupDailyGame() {
        let defaults = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: Date())
        
        // Calculate next puzzle time (tomorrow midnight)
        nextPuzzleDate = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        // Check if we need new daily equation
        if let lastDate = defaults.object(forKey: "LastEquationDate") as? Date,
           Calendar.current.isDate(lastDate, inSameDayAs: today) {
            // Load existing equation
            if let savedEquation = defaults.string(forKey: "DailyEquation") {
                answer = savedEquation
            } else {
                generateComplexEquation()
            }
        } else {
            // Generate new daily equation
            generateComplexEquation()
            defaults.set(today, forKey: "LastEquationDate")
            defaults.removeObject(forKey: lastGameCompletedKey) // Allow new game on new day
            resetDailyGameState()
            resetGameState()
        }
    }
    
    private func resetDailyGameState() {
        // Reset only daily progress (not stats)
        guesses = Array(repeating: Guess(), count: maxGuesses)
        currentGuessIndex = 0
        currentCharIndex = 0
        showEndScreen = false
        keyColors = [:]
        shouldAnimateRow = nil
        
        // Clear stats update flag for new day
        UserDefaults.standard.removeObject(forKey: lastStatsUpdateKey)
        
        saveGameState()
    }
    
    // Generate valid 8-character equation
    private func generateComplexEquation() {
        let operators = ["+", "-", "*", "/"]
        var equation: String?
        var attempts = 0
        
        // Attempt to generate valid equation
        while equation == nil && attempts < 100 {
            attempts += 1
            let numOperators = Int.random(in: 1...2)
            
            if numOperators == 1 {
                let op = ["+", "-"].randomElement()!
                switch op {
                case "+":
                    let A = Int.random(in: 10...49)
                    let B = Int.random(in: 10...(99 - A))
                    let C = A + B
                    equation = "\(A)\(op)\(B)=\(C)"
                    
                case "-":
                    let A = Int.random(in: 20...99)
                    let B = Int.random(in: 10...(A - 10))
                    let C = A - B
                    equation = "\(A)\(op)\(B)=\(C)"
                    
                default: break
                }
            } else {
                // Two-operator pattern: XXoYoZ=W (8 chars)
                let A = Int.random(in: 10...99)
                let op1 = operators.randomElement()!
                let B = Int.random(in: 0...9)
                
                // Validate first operation
                guard op1 != "/" || (B != 0 && A % B == 0) else { continue }
                
                let step1: Int
                switch op1 {
                case "+": step1 = A + B
                case "-": step1 = A - B
                case "*": step1 = A * B
                case "/": step1 = A / B
                default: continue
                }
                guard step1 >= 0 else { continue }
                
                let op2 = operators.randomElement()!
                let C = Int.random(in: 0...9)
                
                // Validate second operation
                guard op2 != "/" || (C != 0 && step1 % C == 0) else { continue }
                
                let step2: Int
                switch op2 {
                case "+": step2 = step1 + C
                case "-": step2 = step1 - C
                case "*": step2 = step1 * C
                case "/": step2 = step1 / C
                default: continue
                }
                guard step2 >= 0 && step2 <= 9 else { continue }
                
                equation = "\(A)\(op1)\(B)\(op2)\(C)=\(step2)"
            }
            
            // Final length validation
            if let eq = equation, eq.count != 8 {
                equation = nil
            }
        }
        
        // Fallback equations if generation fails
        equation = equation ?? [
            "10+10=20",  // Addition
            "50-10=40",  // Subtraction
            "10+2-3=9",  // Two operators
            "20/2*1=10"  // Division and multiplication
        ].randomElement()!
        
        // Save new equation
        UserDefaults.standard.set(equation, forKey: "DailyEquation")
        answer = equation!
    }
    
    // MARK: - Game Logic
    
    // Add character to current guess
    func insertCharacter(_ char: Character) {
        guard !isGameOver else { return }
        guard currentCharIndex < equationLength else { return }
        
        var currentEquation = Array(guesses[currentGuessIndex].equation)
        currentEquation[currentCharIndex] = char
        guesses[currentGuessIndex].equation = String(currentEquation)
        currentCharIndex += 1
    }
    
    // Remove last character from current guess
    func deleteCharacter() {
        guard !isGameOver else { return }
        guard currentCharIndex > 0 else { return }
        
        currentCharIndex -= 1
        var currentEquation = Array(guesses[currentGuessIndex].equation)
        currentEquation[currentCharIndex] = " "
        guesses[currentGuessIndex].equation = String(currentEquation)
    }
    
    // Validate and process current guess
    func submitGuess() {
        guard !isGameOver else { return }
        guard currentCharIndex == equationLength else {
            showToastMessage("Complete the equation first!")
            return
        }
        
        let guessString = guesses[currentGuessIndex].equation
        guard isValidEquation(guessString) else {
            showToastMessage("Invalid equation!")
            return
        }
        
        evaluateGuess()
        shouldAnimateRow = currentGuessIndex - 1  // Trigger animations
        saveGameState()
        
        if isGameOver {
            updateStreak()
            showEndScreen = true
            // Mark game as completed
            UserDefaults.standard.set(Date(), forKey: lastGameCompletedKey)
        }
    }
    
    // Validate equation structure and math
    private func isValidEquation(_ equation: String) -> Bool {
        // Length check
        guard equation.count == equationLength else {
            showToastMessage("Equation must be 8 characters!")
            return false
        }
        
        // Regex pattern validation
        let cleanEquation = equation.replacingOccurrences(of: " ", with: "")
        let pattern = "^\\d+[+\\-*/]\\d+([+\\-*/]\\d+)*=\\d+$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              regex.firstMatch(in: cleanEquation, range: NSRange(cleanEquation.startIndex..., in: cleanEquation)) != nil else {
            return false
        }
        
        // Component extraction
        let components = cleanEquation.split { ["+", "-", "*", "/", "="].contains($0) }
        guard components.count >= 3 else { return false }
        
        // Number conversion
        let numbers = components.compactMap { Int($0) }
        guard numbers.count == components.count else { return false }
        
        // Separate LHS and result
        let leftHandNumbers = Array(numbers.dropLast())
        let resultNumber = numbers.last!
        
        // Operator extraction
        let operatorsPart = cleanEquation.split(separator: "=").first ?? ""
        let operators = operatorsPart.filter { ["+", "-", "*", "/"].contains($0) }
        let operatorArray = Array(operators)
        guard operatorArray.count == leftHandNumbers.count - 1 else { return false }
        
        // Left-to-right evaluation
        var current = leftHandNumbers[0]
        for i in 0..<operatorArray.count {
            let op = operatorArray[i]
            let nextNum = leftHandNumbers[i+1]
            
            switch op {
            case "+": current += nextNum
            case "-": current -= nextNum
            case "*": current *= nextNum
            case "/":
                if nextNum == 0 { return false }
                // Ensure integer division
                guard current % nextNum == 0 else { return false }
                current /= nextNum
            default: break
            }
        }
        
        // Result comparison
        return current == resultNumber
    }
    
    // Evaluate guess against solution
    private func evaluateGuess() {
        var guess = guesses[currentGuessIndex]
        let guessChars = Array(guess.equation)
        var answerChars = Array(answer)
        var frequency = [Character: Int]()  // Character frequency tracking
        
        // Count solution character frequency
        for char in answerChars {
            if char != " " {
                frequency[char, default: 0] += 1
            }
        }
        
        // First pass: mark correct positions (green)
        for i in 0..<equationLength {
            if guessChars[i] == answerChars[i] {
                guess.tileColors[i] = .green
                frequency[guessChars[i], default: 0] -= 1
                answerChars[i] = " " // Mark processed
                
                // Update keyboard (green is highest priority)
                updateKeyColor(char: guessChars[i], newColor: .green)
            }
        }
        
        // Second pass: mark correct chars in wrong positions (yellow)
        for i in 0..<equationLength {
            guard guess.tileColors[i] != .green else { continue }
            
            let char = guessChars[i]
            if char != " " {
                if let count = frequency[char], count > 0 {
                    guess.tileColors[i] = .yellow
                    frequency[char] = count - 1
                    
                    // Only update keyboard if not already green
                    if keyColors[String(char)] != .green {
                        updateKeyColor(char: char, newColor: .yellow)
                    }
                } else {
                    guess.tileColors[i] = .red
                    
                    // Set red only if no existing color
                    if keyColors[String(char)] == nil {
                        updateKeyColor(char: char, newColor: .red)
                    }
                }
            }
        }
        
        // Update game state
        guesses[currentGuessIndex] = guess
        currentGuessIndex += 1
        currentCharIndex = 0
        lastPlayedDate = Date()
        
        // Handle win
        if isSolved {
            // Update best tries record
            if totalGamesWon == 0 || currentGuessIndex < fewestTries {
                fewestTries = currentGuessIndex
                UserDefaults.standard.set(fewestTries, forKey: fewestTriesKey)
            }
            showToastMessage("You solved it!")
        }
    }
    
    // Toast helper
    func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true
    }
    
    // Update keyboard key color with priority logic
    private func updateKeyColor(char: Character, newColor: TileColor) {
        let charKey = String(char)
        if let currentColor = keyColors[charKey] {
            // Priority: green > yellow > red
            if currentColor == .green { return }
            if currentColor == .yellow && newColor == .red { return }
        }
        keyColors[charKey] = newColor
    }
    
    // MARK: - Streak System
    private func updateStreak() {
        let today = Calendar.current.startOfDay(for: Date())
        let defaults = UserDefaults.standard
        
        // Check if stats were already updated today
        if let lastUpdate = defaults.object(forKey: lastStatsUpdateKey) as? Date,
           Calendar.current.isDate(lastUpdate, inSameDayAs: today) {
            print("Stats already updated today, skipping updateStreak")
            return // Prevent double-counting
        }
        
        // Mark stats as updated
        defaults.set(today, forKey: lastStatsUpdateKey)
        print("Updating stats: totalGamesPlayed=\(totalGamesPlayed), totalGamesWon=\(totalGamesWon), isSolved=\(isSolved)")
        
        // Load current streaks
        currentStreak = defaults.integer(forKey: "CurrentStreak")
        bestStreak = defaults.integer(forKey: "BestStreak")
        
        if let lastWinDate = defaults.object(forKey: "LastWinDate") as? Date {
            let lastWinDay = Calendar.current.startOfDay(for: lastWinDate)
            let daysSince = Calendar.current.dateComponents([.day], from: lastWinDay, to: today).day ?? 0
            
            if daysSince == 0 {
                // Already won today - do nothing for streak
            } else if daysSince == 1 {
                // Consecutive day - update streak
                currentStreak = isSolved ? currentStreak + 1 : 0
            } else {
                // Broken streak
                currentStreak = isSolved ? 1 : 0
            }
        } else {
            // First win
            currentStreak = isSolved ? 1 : 0
        }
        
        // Update best streak record
        if currentStreak > bestStreak {
            bestStreak = currentStreak
        }
        
        // Update game stats
        totalGamesPlayed += 1
        
        if isSolved {
            totalGamesWon += 1
            
            // Update win distribution with correct indexing
            let tries = currentGuessIndex
            if tries > 0 && tries <= 6 {
                winDistribution[tries - 1] += 1
                print("Updated winDistribution[\(tries - 1)] = \(winDistribution[tries - 1])")
            }
            
            // Save win date
            defaults.set(today, forKey: "LastWinDate")
        }
        
        // Persist all stats
        defaults.set(currentStreak, forKey: "CurrentStreak")
        defaults.set(bestStreak, forKey: "BestStreak")
        defaults.set(totalGamesPlayed, forKey: totalGamesPlayedKey)
        defaults.set(totalGamesWon, forKey: totalGamesWonKey)
        defaults.set(winDistribution, forKey: winDistributionKey)
        print("Saved stats: totalGamesPlayed=\(totalGamesPlayed), totalGamesWon=\(totalGamesWon), winDistribution=\(winDistribution)")
    }
    
    private func loadStreakData() {
        let defaults = UserDefaults.standard
        currentStreak = defaults.integer(forKey: "CurrentStreak")
        bestStreak = defaults.integer(forKey: "BestStreak")
    }
    
    // MARK: - Persistence
    func saveGameState() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(guesses) {
            UserDefaults.standard.set(data, forKey: "SavedGuesses")
        }
        // Save key game state
        UserDefaults.standard.set(currentGuessIndex, forKey: "CurrentGuessIndex")
        UserDefaults.standard.set(currentCharIndex, forKey: "CurrentCharIndex")
        UserDefaults.standard.set(lastPlayedDate, forKey: "LastPlayedDate")
        UserDefaults.standard.set(totalGamesPlayed, forKey: totalGamesPlayedKey)
        UserDefaults.standard.set(totalGamesWon, forKey: totalGamesWonKey)
        UserDefaults.standard.set(winDistribution, forKey: winDistributionKey)
        
        // Save keyboard colors
        if let keyColorsData = try? JSONEncoder().encode(keyColors) {
            UserDefaults.standard.set(keyColorsData, forKey: "KeyColors")
        }
        print("Saved game state: totalGamesPlayed=\(totalGamesPlayed), totalGamesWon=\(totalGamesWon), winDistribution=\(winDistribution)")
    }
    
    private func loadGameState() {
        let defaults = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: Date())
        
        // Only load game progress if playing same day
        if let lastPlayed = defaults.object(forKey: "LastPlayedDate") as? Date,
           Calendar.current.isDate(lastPlayed, inSameDayAs: today) {
            
            // Load guesses
            if let data = defaults.data(forKey: "SavedGuesses"),
               let savedGuesses = try? JSONDecoder().decode([Guess].self, from: data) {
                guesses = savedGuesses
            }
            
            // Load indices
            currentGuessIndex = defaults.integer(forKey: "CurrentGuessIndex")
            currentCharIndex = defaults.integer(forKey: "CurrentCharIndex")
            
            // Load keyboard colors
            if let keyColorsData = defaults.data(forKey: "KeyColors"),
               let savedKeyColors = try? JSONDecoder().decode([String: TileColor].self, from: keyColorsData) {
                keyColors = savedKeyColors
            }
        }
        // Always load stats to ensure they persist
        loadPersistentStats()
    }
    
    private func resetGameState() {
        // Preserve stats during reset
        let savedStats = (
            totalGamesPlayed: self.totalGamesPlayed,
            totalGamesWon: self.totalGamesWon,
            winDistribution: self.winDistribution
        )
        
        // Reset game progress
        guesses = Array(repeating: Guess(), count: maxGuesses)
        currentGuessIndex = 0
        currentCharIndex = 0
        showEndScreen = false
        keyColors = [:]
        shouldAnimateRow = nil
        
        // Restore stats
        self.totalGamesPlayed = savedStats.totalGamesPlayed
        self.totalGamesWon = savedStats.totalGamesWon
        self.winDistribution = savedStats.winDistribution
        
        saveGameState()
    }
}

// MARK: - Modal View for Rules + Hint

// Modal view showing game instructions and hints
struct RulesModalView: View {
    @ObservedObject var game: GameState
    @Binding var isPresented: Bool  // Controls modal visibility
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .center, spacing: 20) {
                    // Instructions section
                    Divider()
                    Text("Instructions:")
                        .font(.title.bold())
                        .foregroundColor(.white)
                    Text("Guess the equation in up to six tries")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Each equation is exactly 8 characters long")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Equations must be mathematically valid")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Follow the order of operations")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Divider()
                    Spacer()
                    
                    // Tile colors explanation
                    Text("Tile Colors:")
                        .font(.title.bold())
                        .foregroundColor(.white)
                    HStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.green)
                            .frame(width: 20, height: 20)
                        Text("Correct position")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    HStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.yellow)
                            .frame(width: 20, height: 20)
                        Text("Incorrect position")
                            .font(.headline)
                            .foregroundColor(.yellow)
                    }
                    HStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.red)
                            .frame(width: 20, height: 20)
                        Text("Not in the solution")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                    Spacer()
                    Divider()
                    Spacer()
                    
                    // Example hint
                    Text("Hint: Try 12+57=69")
                        .font(.system(size: 30, weight: .bold, design: .default))
                        .foregroundColor(.white)
                }
                .padding()
            }
            .background(Color.black) // Dark theme
            .foregroundColor(.white)
            .toolbar {
                // Close button
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.headline)
                            .padding(10)
                            .foregroundColor(.gray)
                    }
                    .foregroundColor(.white)
                }
            }
            .preferredColorScheme(.dark) // Force dark mode
        }
    }
}

// MARK: - End Game View

// Victory/defeat screen after game completion
struct EndGameView: View {
    @ObservedObject var game: GameState
    @State private var timeRemaining = ""  // Countdown to next puzzle
    // Timer for countdown updates
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var hue: Double = 0.0   // For color animation
    // Timer for color cycling
    let colorTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color.black  // Full-screen background
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // Result title
                Text(game.isSolved ? "Solved in \(game.currentGuessIndex) tries" : "Try again tomorrow!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // Solution display
                VStack {
                    Text("The equation was:")
                        .font(.system(size: 21, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding()
                    Text(game.answer)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hue: hue, saturation: 1, brightness: 1))
                        .onReceive(colorTimer) { _ in updateHue() } // Animate color
                        .padding()
                }
                
                Divider()
                
                // Next puzzle countdown
                VStack {
                    Text("New puzzle in:")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(timeRemaining)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding()
                        .onReceive(timer) { _ in updateTimeRemaining() }
                }
                
                // Close button
                Button(action: {
                    // Return to start screen
                    UIApplication.shared.windows.first?.rootViewController =
                        UIHostingController(rootView: StartView())
                }) {
                    Text("Close")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(LinearGradient(gradient: Gradient(colors: [.pink, .purple]),
                                                   startPoint: .leading,
                                                   endPoint: .trailing))
                        .cornerRadius(20)
                }
                .padding(.top, 20)
            }
            .padding(30)
            .background(Color(.systemGray6))
            .cornerRadius(20)
            .padding(40)
        }
        .onAppear { updateTimeRemaining() }
        .preferredColorScheme(.dark) // Dark mode
    }
    
    // Update countdown display
    private func updateTimeRemaining() {
        guard let nextDate = game.nextPuzzleDate else { return }
        let remaining = Calendar.current.dateComponents([.hour, .minute, .second],
                                                        from: Date(),
                                                        to: nextDate)
        
        if let hours = remaining.hour,
           let minutes = remaining.minute,
           let seconds = remaining.second {
            timeRemaining = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }
    
    // Cycle through hues for color animation
    private func updateHue() {
        hue += 0.01
        if hue > 1.0 { hue = 0.0 }
    }
}

// MARK: - Start View

// Initial app screen with countdown and start button
struct StartView: View {
    @StateObject var game = GameState()       // Game state instance
    @State private var timeRemaining = ""     // Next puzzle countdown
    @State private var hue: Double = 0.0      // For title color animation
    @State private var showStats = false      // Stats modal visibility
    @State private var showSettings = false   // Settings modal visibility
    @State private var showToast = false      // Toast for play restriction
    @State private var toastMessage = ""      // Toast message content
    // Timers for countdown and animation
    let countdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let colorTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color.black  // Full-screen background
                .edgesIgnoringSafeArea(.all)
            
            VStack(alignment: .center, spacing: 20) {
                // Top control buttons
                HStack {
                    // Settings button
                    Spacer().frame(width: 10)
                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(9)
                            .background(LinearGradient(
                                gradient: Gradient(colors: [.pink, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .clipShape(Circle())
                    }
                    .padding(.top, -15)
                    
                    Spacer()
                    
                    // Stats button
                    Button(action: { showStats.toggle() }) {
                        Image(systemName: "chart.bar.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(9)
                            .background(LinearGradient(
                                gradient: Gradient(colors: [.pink, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .clipShape(Circle())
                    }
                    .padding(.top, -15)
                    Spacer().frame(width: 10)
                }
                .frame(maxWidth: .infinity)
                
                Spacer()
                
                // Animated app title
                Text("EQLE")
                    .font(.system(size: 100, weight: .heavy, design: .monospaced))
                    .foregroundColor(Color(hue: hue, saturation: 1, brightness: 1))
                    .shadow(color: Color(hue: hue, saturation: 1, brightness: 1),
                            radius: 10, x: 0, y: 0)
                    .padding(.top, 20)
                
                Spacer()
                
                // Next puzzle countdown
                VStack {
                    Text(game.canPlayToday ? "New Puzzle In:" : "Next Puzzle In:")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text(timeRemaining)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Start game button
                Button(action: {
                    if game.canPlayToday {
                        // Launch game screen
                        UIApplication.shared.windows.first?.rootViewController =
                            UIHostingController(rootView: ContentView())
                    } else {
                        toastMessage = "Come back tomorrow for a new puzzle!"
                        showToast = true
                    }
                }) {
                    Text("Start Daily Puzzle")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.pink, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(20)
                }
                .padding(.top, 20)
                .padding(.horizontal, 40)
            }
            .padding()
        }
        .toast(message: $toastMessage, isShowing: $showToast)
        .onAppear { updateTimeRemaining() }
        .onReceive(countdownTimer) { _ in updateTimeRemaining() }
        .onReceive(colorTimer) { _ in updateHue() }
        // Stats modal
        .sheet(isPresented: $showStats) {
            StatsDetailView(game: game, isPresented: $showStats)
        }
    }
    
    // Update countdown display
    private func updateTimeRemaining() {
        guard let nextDate = game.nextPuzzleDate else { return }
        let remaining = Calendar.current.dateComponents([.hour, .minute, .second],
                                                        from: Date(),
                                                        to: nextDate)
        if let hours = remaining.hour,
           let minutes = remaining.minute,
           let seconds = remaining.second {
            timeRemaining = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }
    
    // Cycle through hues for color animation
    private func updateHue() {
        hue += 0.01
        if hue > 1.0 { hue = 0.0 }
    }
}

// Main game view
struct ContentView: View {
    @StateObject var game = GameState() // Game state instance
    @State private var showingRules = false // Rules modal visibility
    
    var body: some View {
        ZStack {
            Color.black // Full-screen background
                .edgesIgnoringSafeArea(.all)
            VStack {
                TopBarView(showingRules: $showingRules, game: game)
                GameContentView(game: game)
            }
            
            // Show end screen when game finishes
            if game.showEndScreen {
                EndGameView(game: game)
            }
        }
        // Toast notification system
        .toast(message: $game.toastMessage, isShowing: $game.showToast)
        // Save state when app backgrounds
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            game.saveGameState()
        }
    }
}

// MARK: - App Entry Point

// Main app struct
@main
struct EQLEApp: App {
    var body: some Scene {
        WindowGroup {
            StartView() // Initial view
        }
    }
}

// MARK: - Top Bar Subview

// Game screen top navigation
struct TopBarView: View {
    @Binding var showingRules: Bool
    @ObservedObject var game: GameState
    @State private var hue: Double = 0.0 // For title color animation
    // Timer for color animation
    let colorTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack {
            // Home button
            Button(action: {
                UIApplication.shared.windows.first?.rootViewController =
                    UIHostingController(rootView: StartView())
            }) {
                Image(systemName: "house.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .position(x: 50, y: 10)
            }
            
            Spacer()
            
            // Rules button
            Button(action: { showingRules = true }) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .position(x: 150, y: 10)
            }
            .sheet(isPresented: $showingRules) {
                RulesModalView(game: game, isPresented: $showingRules)
            }
        }
        
        // Animated app title
        Text("EQLE")
            .position(x: 200, y: 10)
            .font(.system(size: 120, weight: .heavy, design: .monospaced))
            .foregroundColor(Color(hue: hue, saturation: 1, brightness: 1))
            .onReceive(colorTimer) { _ in updateHue() }
    }
    
    // Cycle through hues for color animation
    private func updateHue() {
        hue += 0.01
        if hue > 1.0 { hue = 0.0 }
    }
}

// MARK: - Game Content Subview

// Container for game components
struct GameContentView: View {
    @ObservedObject var game: GameState
    // Keyboard layout definition
    let keyLayout: [[String]] = [
        ["0", "1", "2", "3", "4"],
        ["5", "6", "7", "8", "9"],
        ["+", "-", "*", "/", "="],
        ["DELETE", "SUBMIT"]
    ]
    
    var body: some View {
        VStack(spacing: 8) {
            StreakDisplayView(game: game)  // Streak stats
            Spacer()
            EquationGridView(game: game)   // Equation grid
            Spacer()
            KeyboardView(game: game, keyLayout: keyLayout) // Virtual keyboard
        }
        .padding()
        .disabled(game.showEndScreen) // Disable interaction during end screen
        .blur(radius: game.showEndScreen ? 5 : 0) // Blur when end screen shows
    }
}

// MARK: - Streak Display Subview

// Streak statistics display
struct StreakDisplayView: View {
    @ObservedObject var game: GameState
    
    var body: some View {
        HStack {
            // Best streak
            VStack {
                Text("BEST")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text("STREAK")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text("\(game.bestStreak)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            
            // Current streak
            VStack {
                Text("CURRENT")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text("STREAK")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text("\(game.currentStreak)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            
            // Fewest tries
            VStack {
                Text("FEWEST")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text("TRIES")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text("\(game.fewestTries)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Equation Grid Subview

// Grid of equation tiles
struct EquationGridView: View {
    @ObservedObject var game: GameState
    
    var body: some View {
        // 6 rows of equations
        ForEach(0..<6, id: \.self) { row in
            HStack(spacing: 7) {
                // 8 characters per equation
                ForEach(0..<8, id: \.self) { col in
                    let equation = game.guesses[row].equation
                    let index = equation.index(equation.startIndex, offsetBy: col)
                    let char = equation[index]
                    let tileColor = game.guesses[row].tileColors[col]
                    
                    // Create tile with animation parameters
                    TileView(
                        character: String(char),
                        color: tileColor,
                        shouldAnimate: game.shouldAnimateRow == row,
                        delay: Double(col) * 0.2  // Staggered animation
                    )
                }
            }
        }
    }
}

// MARK: - Keyboard Subview

// Virtual keyboard view
struct KeyboardView: View {
    @ObservedObject var game: GameState
    let keyLayout: [[String]]  // Keyboard layout
    
    var body: some View {
        VStack(spacing: 15) {
            // Create rows from layout
            ForEach(keyLayout, id: \.self) { row in
                HStack(spacing: 10) {
                    // Create keys in row
                    ForEach(row, id: \.self) { key in
                        Button(action: { handleKeyTap(key) }) {
                            Text(key)
                                .font(.system(size: 20, weight: .bold))
                                .frame(minHeight: 44)
                                .frame(maxWidth: .infinity)
                                .background(keyBackground(key))  // Key color
                                .foregroundColor(keyForeground(key))  // Text color
                                .cornerRadius(8)
                        }
                        // Wider buttons for special keys
                        .frame(width: key == "DELETE" || key == "SUBMIT" ? 165 : nil)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    // Determine key background color
    private func keyBackground(_ key: String) -> Color {
        // Special key colors
        if key == "DELETE" { return Color.red.opacity(1) }
        if key == "SUBMIT" { return Color.green.opacity(1) }
        return Color.gray.opacity(0.6)  // Default
    }
    
    // Determine key text color
    private func keyForeground(_ key: String) -> Color {
        // Special key colors
        if key == "DELETE" || key == "SUBMIT" { return .black }
        // Color-coded based on previous guesses
        if let color = game.keyColors[key] {
            switch color {
            case .red: return .red
            case .green: return .green
            case .yellow: return .yellow
            default: return .white
            }
        }
        return .white  // Default
    }
    
    // Handle key presses
    private func handleKeyTap(_ key: String) {
        switch key {
        case "DELETE":
            game.deleteCharacter()
        case "SUBMIT":
            game.submitGuess()
        default:
            if let char = key.first {
                game.insertCharacter(char)
            }
        }
    }
}

// MARK: - Statistics Detail View

// Detailed statistics modal
struct StatsDetailView: View {
    @ObservedObject var game: GameState
    @Binding var isPresented: Bool  // Modal visibility
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary statistics
                    VStack(spacing: 16) {
                        Text("Game Statistics")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                        
                        // Stat boxes
                        HStack(spacing: 12) {
                            StatBox(title: "Played", value: "\(game.totalGamesPlayed)")
                            StatBox(title: "Wins", value: "\(game.totalGamesWon)")
                            StatBox(title: "Win %", value: winPercentage)
                        }
                        
                        HStack(spacing: 12) {
                            StatBox(title: "Streak", value: "\(game.currentStreak)")
                            StatBox(title: "Best Streak", value: "\(game.bestStreak)")
                            StatBox(title: "Best Try", value: "\(game.fewestTries)")
                        }
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Guess distribution chart
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Guess Distribution")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding(.bottom, 4)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(1..<7) { tryCount in
                                HStack(spacing: 8) {
                                    Text("\(tryCount)")
                                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                                        .foregroundColor(.white)
                                        .frame(width: 24, alignment: .center)
                                    
                                    // Calculate bar width
                                    let count = game.winDistribution[tryCount-1]
                                    let maxValue = max(game.winDistribution.max() ?? 1, 1)
                                    let barWidth = CGFloat(count) / CGFloat(maxValue) * 200 // Adjusted for better scaling
                                    
                                    ZStack(alignment: .leading) {
                                        // Background bar
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color(.systemGray5))
                                            .frame(height: 28)
                                        
                                        // Colored bar
                                        if count > 0 {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(LinearGradient(
                                                    gradient: Gradient(colors: [.blue, .purple]),
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                ))
                                                .frame(width: max(barWidth, 10), height: 28) // Ensure minimum width for visibility
                                        }
                                        
                                        // Count label
                                        Text("\(count)")
                                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
            .background(Color.black)
            .navigationTitle("Player Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Done button
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { isPresented = false }
                        .font(.body.weight(.medium))
                        .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark) // Dark mode
    }
    
    // Win percentage calculation
    private var winPercentage: String {
        guard game.totalGamesPlayed > 0 else { return "0%" }
        let percentage = (Double(game.totalGamesWon) / Double(game.totalGamesPlayed)) * 100
        return String(format: "%.0f%%", percentage)
    }
}

// MARK: - Stat Box Component

// Reusable statistics display component
struct StatBox: View {
    let title: String  // Stat title
    let value: String  // Stat value
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(Color(.lightGray))
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.systemGray5))
        .cornerRadius(8)
    }
}
