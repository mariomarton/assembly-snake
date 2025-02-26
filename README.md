


# assembly-snake

## Snake Game in Assembly Language for QtMips Environment

## QtMips Settings

- No pipeline, no cache
- Delay slot ON
- OS emulation options as follows ->

## Game Behaviour

- Featuring two manually-controlled snakes
- **RED SNAKE** is controlled by:
  - The red RGB knob or `WSAD` keys
- **BLUE SNAKE** is controlled by:
  - The blue RGB knob or `IKJL` keys
- The snakes use the two LED lights as described in the assignment
- On Game Over, the game intentionally breaks; please recompile to play again

I couldn’t figure out how to use the random system call for generating food positions. Instead, I use pre-generated random positions. Optionally, the player can make the game more random by entering a `1-10` integer in the `OPTIONAL_NUMBER` constant at the start of the code (this changes the pre-generated positions).

## Key Methods

For more detailed information, see the comments in the code.

### `drawPoint(address, color)`
Method with a nested for-loop that draws an **8x8 pixel square** in the given color on the specified address.

### `drawSnake(length, address, direction, color)`
Draws the two snakes at initialization. Returns the snake’s **head** (`$a1`) and **tail** (`$a2`).

### `updateSnake(head, tail, snakeNumber, color, direction)`
Moves the snake by adding a **new head** and removing the **old tail**.
- Includes **collision detection**, **extension when eating food**, and more.
- Returns the updated **head** (`$a1`) and **tail** (`$a2`).

### `checkChange(tail, snakeNumber)`
Used inside `updateSnake()` to determine where the tail goes next.
- The addresses where the snake **changes direction** are saved in an array.
- This method looks for the (old) tail in the array to check if that is where the snake changed direction.

### `mainLoop()`
The **core game loop** that:
- Calls `updateSnake()` for both snakes.
- Checks and validates input from the **keyboard** and **knobs**.



