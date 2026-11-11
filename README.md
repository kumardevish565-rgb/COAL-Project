# COAL-Project

<div align="center">
  <img src="https://img.shields.io/badge/Assembly-x86%20MASM-007ACC?style=for-the-badge&logo=assemblyscript" alt="x86 MASM" />
  <img src="https://img.shields.io/badge/Project-COAL%20Lab-0A6EBD?style=for-the-badge" alt="COAL Lab" />
</div>

A professional x86 Assembly project developed for the COAL (Computer Organization and Assembly Language) lab, focusing on a traffic-monitoring simulation implemented in MASM using the Irvine32 library.

## Overview

This project demonstrates the use of low-level assembly instructions to model and evaluate traffic flow across four directions:

- North
- South
- East
- West

The program tracks vehicle counts in each direction and determines the dominant traffic direction based on the highest count. It also responds to keyboard input to increment the count for a selected direction in real time.

## Key Features

- x86 Assembly implementation using MASM
- Real-time vehicle counter management
- Direction-based traffic comparison
- Keyboard-driven input handling
- Simple and efficient control flow logic
- Demonstrates assembly language concepts such as branching, comparison, and data handling

## System Behavior

The program:

1. Initializes counters for all four directions.
2. Compares the current traffic counts.
3. Identifies the direction with the maximum traffic volume.
4. Waits for user input to update the selected direction.
5. Continues looping until the program ends.

## Project Structure

```text
COAL-Project/
├── README.md
├── project.asm
└── .gitignore
```

## Requirements

To build and run this project, you need:

- Windows Operating System
- MASM / Microsoft Assembler
- Irvine32 library (`irvine32.inc`)
- A compatible assembler environment such as Visual Studio or an MASM development setup

## Build Instructions

1. Open the project in a MASM-supported environment.
2. Ensure `irvine32.inc` is available in the include path.
3. Assemble and link `project.asm`.
4. Run the generated executable.

Example workflow in a MASM-enabled environment:

```asm
INCLUDE irvine32.inc
```

Then assemble the source file and execute the compiled program.

## How to Use

- Press `N` to increment north traffic
- Press `S` to increment south traffic
- Press `E` to increment east traffic
- Press `W` to increment west traffic

The program compares the counts and continues evaluating traffic flow dynamically.

## Learning Outcomes

This project helps reinforce:

- Assembly language fundamentals
- Arithmetic and comparison instructions
- Conditional branching
- Looping structures
- Input handling in low-level programming
- Practical x86 register operations

## License

This project is intended for academic and educational purposes as part of the COAL Lab curriculum.

## Author

Developed for the COAL Lab project in x86 Assembly.

---

If you want, I can also create a more advanced version of this README with:

- a project logo/header banner,
- installation screenshots style sections,
- a GitHub badge set,
- a more detailed workflow diagram,
- or a version tailored specifically for academic submission.
