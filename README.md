#  Bin Packing Problem — MIPS Assembly

> **ENCS4370 — Computer Architecture | Spring 2024/2025 | Birzeit University**

A MIPS assembly implementation of the classic **Bin Packing Problem** using two online heuristics: **First Fit (FF)** and **Best Fit (BF)**. Built to run in the [MARS (MIPS Assembler and Runtime Simulator)](http://courses.missouristate.edu/kenvollmar/mars/).

---

##  Problem Definition

Given *n* items with sizes S₁, S₂, … Sₙ (each a float in `(0.0, 1.0]`), pack them into the **minimum number of unit-capacity bins**.

| Heuristic | Strategy |
|-----------|----------|
| **First Fit (FF)** | Place each item in the **first** bin that has enough space |
| **Best Fit (BF)** | Place each item in the **fullest** bin that still fits it |

---

##  How to Run

### Prerequisites
Download and install **MARS 4.5** (Java-based MIPS simulator):  
 http://courses.missouristate.edu/kenvollmar/mars/

### Steps
1. Open MARS
2. `File → Open` → select `BinPacking.asm`
3. Press **F3** to Assemble
4. Press **F5** to Run
5. In the Run I/O panel, enter the input file path when prompted

---

##  Input File Format

A plain `.txt` file containing floating-point numbers between `0.0` and `1.0`, separated by **spaces**, **newlines**, or **tabs**.

**Example (`items.txt`):**
```
0.5 0.3 0.7
0.2 0.8 0.4
0.1 0.6 0.9
```

Numbers outside the valid range or with invalid format are **silently skipped** with appropriate error messages.

---

##  Menu Options

```
Welcome to Bin Packing Problem Solution Program
-------------------------------------------------------------------------
Please Select an Operation from the Menu:
-------------------------------------------------------------------------
1- Please press 'FF' to display first fit heuristic.
2- Please press 'BF' or 'F' to display best fit heuristic.
3- Please press 'W' to write results to output file.
4- Please press 'Q' to quit the program.
```

| Command | Action | Case Sensitive? |
|---------|--------|----------------|
| `FF` | Run First Fit | No |
| `BF` or `F` | Run Best Fit | No |
| `W` | Save last result to output file | No |
| `Q` | Quit the program | No |

---

##  Output Format

### Console Output
```
Number of bins used: 4
Bin 1: Item 1 (0.5), Item 2 (0.3)
Bin 2: Item 3 (0.7), Item 6 (0.2)
Bin 3: Item 4 (0.8)
Bin 4: Item 5 (0.4), Item 7 (0.1)
```

### File Output (via `W` command)
Same format written to the specified output file.

---

##  Implementation Details

### File I/O
- MARS syscalls 13/14/15/16 for open/read/write/close
- Reads up to 4096 bytes per file

### Parsing
- Validates each token as a float in `(0.0, 1.0)`
- Uses a custom floating-point parser (integer + fractional parts)
- Tolerates multiple delimiters; skips invalid tokens

### First Fit Algorithm
```
for each item i:
    for each existing bin j (in order):
        if bin_capacity[j] - item_size >= -tolerance:
            place item in bin j
            break
    if no bin found:
        open a new bin, place item there
```

### Best Fit Algorithm
```
for each item i:
    best_bin = -1,  best_remaining = 1.1  (sentinel)
    for each existing bin j:
        remaining = bin_capacity[j] - item_size
        if remaining >= -tolerance AND remaining < best_remaining:
            best_bin = j
            best_remaining = remaining
    if best_bin == -1:
        open a new bin
    else:
        place item in best_bin
```

### Data Structures
| Structure | Size | Description |
|-----------|------|-------------|
| `items[]` | 100 floats | Parsed item sizes |
| `bin_capacity[]` | 100 floats | Remaining capacity per bin |
| `bin_contents[]` | 10000 words (100 bins × 100 slots) | Item indices per bin |

### Floating-Point Tolerance
A tolerance of `0.0001` is used in all capacity comparisons to handle floating-point rounding errors.

---

##  Limitations
- Maximum **100 items**
- Maximum **100 bins**
- Maximum **100 items per bin** (in storage)
- Input file size up to **4096 bytes**

---

##  Tools Used
- **Language:** MIPS Assembly
- **Simulator:** MARS 4.5
- **Architecture:** MIPS32

