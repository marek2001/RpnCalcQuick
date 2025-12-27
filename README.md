# RpnCalcQuick - RPN Calculator

RpnCalcQuick is a modern Reverse Polish Notation (RPN) calculator built with C++20 and Qt 6. It utilizes the Model-View-ViewModel (MVVM) architecture, leveraging C++ for the core logic and efficient stack management, and Qt Quick (QML) for a responsive user interface.

## Features

* **RPN Logic:** Classic stack-based calculation method.
* **Dynamic Stack:** View, scroll, and manipulate the stack in real-time.
* **Number Formatting:**
    * **Scientific:** Standard scientific notation (e.g., `1.23 * 10^5`).
    * **Engineering:** Exponents are multiples of 3.
    * **Simple:** Standard decimal notation.
* **Configurable Precision:** Adjust the number of decimal places or significant digits.
* **Stack Manipulation:**
    * Swap, Duplicate, and Drop operations.
    * Move items up/down the stack visually.
    * Edit values directly in the stack list (supports input like `3.2*10^5`).
* **History Log:** Keeps a textual record of all operations and results.
* **Input Support:** Full support for on-screen keypad, numpad, and standard keyboard shortcuts.

## Requirements

* **C++ Compiler:** C++20 standard required.
* **Qt Framework:** Version 6.2 or later.
    * Modules: `QtQuick`, `QtQml`, `QtQuick.Controls`, `Qt.labs.platform`.
* **CMake:** Version 3.21 or later.

## Build Instructions

1.  Clone or download the repository.
2.  Create a build directory:
    ```bash
    mkdir build
    cd build
    ```
3.  Configure the project using CMake:
    ```bash
    cmake ..
    ```
4.  Build the application:
    ```bash
    cmake --build .
    ```

## Usage

### Basic Operation
In RPN mode, operators follow their operands.
**Example:** To calculate `(3 + 4) * 5`:
1.  Type `3`, press `Enter`.
2.  Type `4`, press `Enter`.
3.  Press `+` (Result `7` is on stack).
4.  Type
