# Bin Packing Problem Solution Using MIPS Assembly
# Yasmen Itawy 1221426
.data

# --- User I/O Buffers --- #
prompt_msg:      .asciiz "Enter the input file name or path: "
filename:        .space 100
buffer:          .space 4096
menu_input:      .space 100
prompt_outfile:  .asciiz "Enter output file name or path: "
outfile:         .space 100
buf1:            .space 1

# --- Parsed Items Storage --- #
items:           .float 0.0:100
item_count:      .word 0

# --- Error Messages --- #
err_open:        .asciiz "Error: Could not open file\n"
err_read:        .asciiz "Error: Could not read file\n"
err_num:         .asciiz "Error: Invalid number format at byte position "
err_range:       .asciiz "Error: Number out of range (must be 0.0-1.0) at byte position "
err_option:      .asciiz "Invalid option. Try again.\n"

# --- Status Messages --- #
msg_success:     .asciiz "Successfully parsed "
msg_count:       .asciiz " valid numbers\n"
newline:         .asciiz "\n"
valid_items_msg: .asciiz "\nValid items parsed:\n"

# --- Bin-Packing Data --- #
bin_capacity:  .float 1.0:100
bin_contents:  .word -1:10000            # Expanded to allow up to 100 items per bin safely
bin_count:     .word 0

# --- Floating-Point Constants --- #
one:           .float 1.0
zero_float:    .float 0.0
x:             .float 1.1                # Best-fit sentinel (larger than any valid remaining)
tol:           .float 0.0001             # Tolerance for floating-point comparisons

# --- Output Formatting Strings --- #
msg_bin_count: .asciiz "Number of bins used: "
msg_bin_label: .asciiz "Bin "
msg_item_label:.asciiz "Item "
colon_space:   .asciiz ": "
comma_space:   .asciiz ", "
open_paren:    .asciiz " ("
close_paren:   .asciiz ")"

# --- Display Menu Strings --- #
welcome:  .asciiz "Welcome to Bin Packing Problem Solution Program\n"
menuOp:   .asciiz "Please Select an Operation from the Menu: \n"
option1:  .asciiz "1- Please press 'FF' to display first fit heuristic. \n"
option2:  .asciiz "2- Please press 'BF' or 'F' to display best fit heuristic. \n"
option3:  .asciiz "3- Please press 'W' to write results to output file.\n"
option4:  .asciiz "4- Please press 'Q' to quit the program.\n\nYour Choice:"
split:    .asciiz "\n-------------------------------------------------------------------------\n"

# --- Menu Option Strings (lowercase for comparison) --- #
ff:    .asciiz "ff"
bf:    .asciiz "bf"
f_str: .asciiz "f"          
q:     .asciiz "q"
w:     .asciiz "w"

# --- File Output Buffers --- #
prompt_filename:  .asciiz "Enter the output file name: "
output_filename:  .space 100
save_choice:      .space 3
err_open_output:  .asciiz "Error: Could not open output file\n"
buffer_convert:   .space 12   # For integer_to_string conversion
buffer_output:    .space 4096

#========================= .text =========================#
.text
.globl main

#------------------------- main -------------------------#
main:
    # Print prompt asking for filename
    li $v0, 4
    la $a0, prompt_msg
    syscall

    # Read filename from user input
    li $v0, 8
    la $a0, filename
    li $a1, 100
    syscall

    # Remove newline character from filename
    la $t0, filename
remove_newline:
    lb $t1, ($t0)
    beq $t1, '\n', replace_newline
    beqz $t1, open_file
    addi $t0, $t0, 1
    j remove_newline
replace_newline:
    sb $zero, ($t0)

open_file:
    li $v0, 13
    la $a0, filename
    li $a1, 0              # Read-only
    syscall
    bltz $v0, error_open
    move $s0, $v0          # Save file descriptor

    # Read file contents
    li $v0, 14
    move $a0, $s0
    la $a1, buffer
    li $a2, 4096
    syscall
    bltz $v0, error_read
    move $s1, $v0

    # Close the file
    li $v0, 16
    move $a0, $s0
    syscall

    # Initialize parsing variables
    la $t0, buffer
    la $t1, items
    li $t9, 0              # Item counter
    li $t2, 0              # Integer part
    li $t3, 0              # Fractional part
    li $t4, 0              # Fractional digit count
    li $t5, 0              # Flag: 0=integer, 1=fractional
    move $s2, $t0          # Position for error reporting

parse_loop:
    lb $t6, ($t0)
    beqz $t6, done_parse

    li $t7, ' '
    beq $t6, $t7, process_delimiter
    li $t7, '\n'
    beq $t6, $t7, process_delimiter
    li $t7, '\r'
    beq $t6, $t7, process_delimiter
    li $t7, '\t'
    beq $t6, $t7, process_delimiter

    li $t7, '.'
    beq $t6, $t7, process_decimal

    blt $t6, '0', skip_invalid_number
    bgt $t6, '9', skip_invalid_number

    subi $t6, $t6, '0'

    bnez $t5, process_fraction

    # Integer part
    mul $t2, $t2, 10
    add $t2, $t2, $t6
    j next_char

process_fraction:
    mul $t3, $t3, 10
    add $t3, $t3, $t6
    addi $t4, $t4, 1
    j next_char

process_decimal:
    bnez $t5, skip_invalid_number  # Multiple decimal points = invalid
    li $t5, 1
    j next_char

skip_invalid_number:
    lb $t6, ($t0)
    beqz $t6, done_parse
    li $t7, ' '
    beq $t6, $t7, reset_parsing
    li $t7, '\n'
    beq $t6, $t7, reset_parsing
    li $t7, '\r'
    beq $t6, $t7, reset_parsing
    li $t7, '\t'
    beq $t6, $t7, reset_parsing
    addi $t0, $t0, 1
    j skip_invalid_number

reset_parsing:
    li $t2, 0
    li $t3, 0
    li $t4, 0
    li $t5, 0
    move $s2, $t0
    j next_char

process_delimiter:
    # Check if we have gathered any digit
    or $t7, $t2, $t3
    bnez $t7, handle_conversion
    # If t5 was set (e.g. trailing dot), it might need checking, but if zero digits, skip
    j next_char

handle_conversion:
    jal convert_and_validate
    bnez $v0, skip_invalid_number

    s.s $f0, ($t1)
    addi $t1, $t1, 4
    addi $t9, $t9, 1

    li $t2, 0
    li $t3, 0
    li $t4, 0
    li $t5, 0
    move $s2, $t0
    j next_char

convert_and_validate:
    # --- Edge Case Handling for 1.0 ---
    li $t7, 1
    beq $t2, $t7, check_one_exact
    bgt $t2, $t7, invalid_format    # If integer part > 1, invalid
    j proceed_conversion

check_one_exact:
    bnez $t3, invalid_format       # 1.x where x != 0 is invalid (e.g. 1.05)
    l.s $f0, one
    li $v0, 0
    jr $ra

proceed_conversion:
    mtc1 $t2, $f1
    cvt.s.w $f1, $f1               # f1 = 0.0

    mtc1 $t3, $f2
    cvt.s.w $f2, $f2               # f2 = fractional digits as integer

    li $t7, 10
    mtc1 $t7, $f3
    cvt.s.w $f3, $f3               # f3 = 10.0
    li $t7, 1
    mtc1 $t7, $f4
    cvt.s.w $f4, $f4               # f4 = 1.0 (scaling factor)

scale_loop:
    blez $t4, scale_done
    mul.s $f4, $f4, $f3
    subi $t4, $t4, 1
    j scale_loop

scale_done:
    div.s $f2, $f2, $f4            # f2 = fractional value
    add.s $f0, $f1, $f2            # f0 = final float

    # Ensure final value <= 1.0 and >= 0.0
    l.s $f5, one
    c.le.s $f0, $f5
    bc1f invalid_format
    
    li $v0, 0                      # Return success
    jr $ra

invalid_format:
    li $v0, 1                      # Return error
    jr $ra

next_char:
    addi $t0, $t0, 1
    j parse_loop

done_parse:
    or $t7, $t2, $t3
    beqz $t7, parsing_complete

    jal convert_and_validate
    bnez $v0, parsing_complete

    s.s $f0, ($t1)
    addi $t9, $t9, 1

parsing_complete:
    sw $t9, item_count

    # Print success message
    li $v0, 4
    la $a0, msg_success
    syscall
    li $v0, 1
    lw $a0, item_count
    syscall
    li $v0, 4
    la $a0, msg_count
    syscall

    li $v0, 4
    la $a0, valid_items_msg
    syscall

    # Print all parsed items
    lw  $t0, item_count
    li  $t1, 0
print_items_loop2:
    beq $t1, $t0, after_print_items
    la  $t2, items
    sll $t3, $t1, 2
    add $t2, $t2, $t3
    l.s $f12, ($t2)
    li  $v0, 2
    syscall
    li  $v0, 4
    la  $a0, newline
    syscall
    addi $t1, $t1, 1
    j   print_items_loop2

after_print_items:
    j menu

#=============================== MENU ===============================#

menu:
    li $v0, 4
    la $a0, welcome
    syscall

start:
    li $v0, 4
    la $a0, split
    syscall

    li $v0, 4
    la $a0, menuOp
    syscall

    li $v0, 4
    la $a0, split
    syscall

    li $v0, 4
    la $a0, option1
    syscall

    li $v0, 4
    la $a0, option2
    syscall

    li $v0, 4
    la $a0, option3
    syscall

    li $v0, 4
    la $a0, option4
    syscall

    li $v0, 8
    la $a0, menu_input
    li $a1, 100
    syscall

    # Strip trailing newline
    la   $t0, menu_input
strip_nl:
    lb   $t1, 0($t0)
    beq  $t1, '\n', strip_done
    beq  $t1, '\r', strip_done
    beqz $t1, strip_done
    addi $t0, $t0, 1
    j    strip_nl
strip_done:
    sb   $zero, 0($t0)

    # Convert input to lowercase
    la $t0, menu_input
to_lower_loop:
    lb $t1, 0($t0)
    beqz $t1, to_lower_done
    li $t2, 65                 # 'A'
    li $t3, 90                 # 'Z'
    blt $t1, $t2, skip_lower
    bgt $t1, $t3, skip_lower
    addi $t1, $t1, 32          # to lowercase
    sb $t1, 0($t0)
skip_lower:
    addiu $t0, $t0, 1
    j to_lower_loop
to_lower_done:

    # Compare options
    la $a0, menu_input
    la $a1, ff
    jal str_equal
    beq $v0, 1, do_ff

    la $a0, menu_input
    la $a1, bf
    jal str_equal
    beq $v0, 1, do_bf

    la $a0, menu_input
    la $a1, f_str
    jal str_equal
    beq $v0, 1, do_bf

    la $a0, menu_input
    la $a1, q
    jal str_equal
    beq $v0, 1, do_quit

    la $a0, menu_input
    la $a1, w
    jal str_equal
    beq $v0, 1, save_to_file

    # Invalid option
    li $v0, 4
    la $a0, err_option
    syscall
    j start

#=============================== str_equal ===============================#

str_equal:
    li $v0, 1
str_eq_loop:
    lb $t0, 0($a0)
    lb $t1, 0($a1)
    bne $t0, $t1, str_not_equal
    beqz $t0, str_equal_done
    addiu $a0, $a0, 1
    addiu $a1, $a1, 1
    j str_eq_loop
str_not_equal:
    li $v0, 0
str_equal_done:
    jr $ra

#=============================== First Fit ===============================#

do_ff:
    jal    init_bins
    la $s0, items
    lw $s1, item_count
    li $t0, 0              # Item index
    li $t1, 0              # Bin count
    la $t4, bin_capacity
    la $t6, bin_contents

first_fit_loop:
    bge $t0, $s1, ff_done

    sll $t2, $t0, 2
    add $t2, $s0, $t2
    l.s $f0, ($t2)         # f0 = item size

    li $t3, 0              # Bin index j

find_bin_loop:
    bge   $t3, $t1, new_bin

    sll   $t5, $t3, 2
    add   $t5, $t4, $t5
    l.s   $f1, ($t5)       # f1 = bin_capacity[j]

    sub.s $f2, $f1, $f0    # f2 = remaining space

    l.s   $f3, tol
    add.s $f4, $f2, $f3    # f4 = remaining + tolerance
    l.s   $f5, zero_float
    c.lt.s $f4, $f5        # if (remaining + tol) < 0 => cannot fit
    bc1t  next_bin

    # Item fits: update capacity
    s.s   $f2, ($t5)

    # Store item index (Supports up to 100 entries per bin step)
    li    $t7, 0
    mul   $t5, $t3, 400    # Step offset is 400 bytes (100 words)
    add   $t5, $t6, $t5
find_slot_loop:
    lw    $t8, ($t5)
    bltz  $t8, store_item
    addi  $t5, $t5, 4
    addi  $t7, $t7, 1
    blt   $t7, 100, find_slot_loop

store_item:
    sw    $t0, ($t5)
    j     next_item

next_bin:
    addi  $t3, $t3, 1
    j     find_bin_loop

new_bin:
    l.s   $f2, one
    sub.s $f1, $f2, $f0    # new capacity = 1.0 - item_size

    sll $t5, $t1, 2
    add $t5, $t4, $t5
    s.s $f1, ($t5)

    mul $t5, $t1, 400
    add $t5, $t6, $t5
    sw $t0, ($t5)

    addi $t1, $t1, 1
    sw $t1, bin_count

next_item:
    addi $t0, $t0, 1
    j first_fit_loop

ff_done:
    sw   $t1, bin_count
    j    print_results

#=============================== Best Fit ===============================#

do_bf:
    jal    init_bins
    la   $s0, items
    lw   $s1, item_count
    la   $s2, bin_capacity
    la   $s4, bin_contents
    lw   $s3, bin_count
    li   $t9, 0            # Item index i
    l.s  $f5, zero_float

bf_loop:
    bge  $t9, $s1, bf_done

    sll  $t0, $t9, 2
    add  $t0, $s0, $t0
    l.s  $f1, ($t0)        # f1 = item size

    li   $t5, -1           # best_bin = -1
    l.s  $f3, x            # best_remaining = 1.1 (sentinel)
    li   $t8, 0            # bin index j

bf_search:
    bge  $t8, $s3, bf_search_done

    sll  $t0, $t8, 2
    add  $t0, $s2, $t0
    l.s  $f2, ($t0)        # f2 = bin_capacity[j]

    sub.s $f6, $f2, $f1    # f6 = remaining space

    l.s   $f7, tol
    add.s $f4, $f6, $f7    
    c.lt.s $f4, $f5        # if (remaining + tol) < 0 => skip
    bc1t bf_next_bin

    c.lt.s $f6, $f3        # if f6 < best_remaining => tighter fit found
    bc1f bf_next_bin       
    mov.s $f3, $f6         
    move $t5, $t8          

bf_next_bin:
    addi $t8, $t8, 1
    j    bf_search

bf_search_done:
    bltz $t5, bf_create_new  

    # Place item in best_bin
    sll  $t0, $t5, 2
    add  $t0, $s2, $t0
    l.s  $f2, ($t0)
    sub.s $f2, $f2, $f1    
    s.s  $f2, ($t0)

    li   $t7, 0
    mul  $t0, $t5, 400
    add  $t0, $s4, $t0
bf_store_loop:
    lw   $t1, ($t0)
    bltz $t1, bf_store
    addi $t0, $t0, 4
    addi $t7, $t7, 1
    blt  $t7, 100, bf_store_loop
bf_store:
    sw   $t9, ($t0)
    j    bf_next_item

bf_create_new:
    l.s   $f2, one
    sub.s $f2, $f2, $f1    
    sll   $t0, $s3, 2
    add   $t0, $s2, $t0
    s.s   $f2, ($t0)

    mul   $t0, $s3, 400
    add   $t0, $s4, $t0
    sw    $t9, ($t0)

    addi  $s3, $s3, 1      

bf_next_item:
    addi $t9, $t9, 1
    j    bf_loop

bf_done:
    sw   $s3, bin_count
    j    print_results

#=============================== Print Results ===============================#

print_results:
    li $v0, 4
    la $a0, msg_bin_count
    syscall
    lw $a0, bin_count
    li $v0, 1
    syscall
    li $v0, 4
    la $a0, newline
    syscall

    la $s4, bin_contents
    la $s0, items
    lw $s5, bin_count
    li $t3, 0              # Bin index

print_bins_loop:
    bge $t3, $s5, after_print

    li $v0, 4
    la $a0, msg_bin_label
    syscall
    move $a0, $t3
    addi $a0, $a0, 1       
    li $v0, 1              
    syscall
    li $v0, 4
    la $a0, colon_space
    syscall

    mul $t5, $t3, 400
    add $t5, $s4, $t5
    li $t7, 0              

print_items_loop:
    lw $t8, ($t5)
    bltz $t8, print_next_bin

    beqz $t7, skip_comma
    li $v0, 4
    la $a0, comma_space
    syscall

skip_comma:
    li $v0, 4
    la $a0, msg_item_label
    syscall
    move $a0, $t8
    addi $a0, $a0, 1       
    li $v0, 1
    syscall
    li $v0, 4
    la $a0, open_paren
    syscall

    sll $t9, $t8, 2
    add $t9, $s0, $t9
    l.s $f12, ($t9)
    li $v0, 2
    syscall

    li $v0, 4
    la $a0, close_paren
    syscall

    addi $t5, $t5, 4
    addi $t7, $t7, 1
    blt $t7, 100, print_items_loop

print_next_bin:
    li $v0, 4
    la $a0, newline
    syscall
    addi $t3, $t3, 1
    j print_bins_loop

after_print:
    j start                

#=============================== Save to File ===============================#

save_to_file:
    li    $v0, 4
    la    $a0, prompt_filename
    syscall

    li    $v0, 8
    la    $a0, output_filename
    li    $a1, 100
    syscall

    la    $t0, output_filename
remove_newline_filename:
    lb    $t1, 0($t0)
    beq   $t1, '\n', replace_newline_filename
    beq   $t1, '\r', replace_newline_filename
    beqz  $t1, open_file_write
    addiu $t0, $t0, 1
    j     remove_newline_filename
replace_newline_filename:
    sb    $zero, 0($t0)

open_file_write:
    li    $v0, 13
    la    $a0, output_filename
    li    $a1, 1               
    li    $a2, 0
    syscall
    bltz  $v0, error_open_output
    move  $s6, $v0             # Save output file descriptor

    li    $v0, 15
    move  $a0, $s6
    la    $a1, msg_bin_count
    li    $a2, 21
    syscall

    lw    $a0, bin_count
    jal   integer_to_string    
    move  $a1, $v0             
    la    $t0, buffer_convert
    addiu $t0, $t0, 11         
    sub   $a2, $t0, $a1        
    li    $v0, 15
    move  $a0, $s6
    syscall

    li    $v0, 15
    move  $a0, $s6
    la    $a1, newline
    li    $a2, 1
    syscall

    la    $s4, bin_contents
    lw    $s5, bin_count
    li    $t3, 0               

bin_loop:
    bge   $t3, $s5, close_and_return

    li    $v0, 15
    move  $a0, $s6
    la    $a1, msg_bin_label
    li    $a2, 4
    syscall

    addi  $a0, $t3, 1          
    jal   integer_to_string
    move  $a1, $v0
    la    $t0, buffer_convert
    addiu $t0, $t0, 11
    sub   $a2, $t0, $a1
    li    $v0, 15
    move  $a0, $s6
    syscall

    li    $v0, 15
    move  $a0, $s6
    la    $a1, colon_space
    li    $a2, 2
    syscall

    mul   $t2, $t3, 400
    add   $t2, $s4, $t2
    li    $t4, 0               

item_loop:
    lw    $t5, 0($t2)          
    bltz  $t5, end_items       

    beqz  $t4, skip_comma2
    li    $v0, 15
    move  $a0, $s6
    la    $a1, comma_space
    li    $a2, 2
    syscall
skip_comma2:

    li    $v0, 15
    move  $a0, $s6
    la    $a1, msg_item_label
    li    $a2, 5
    syscall

    move  $t7, $t2             # Save slot address pointer
    addi  $a0, $t5, 1          
    jal   integer_to_string    
    move  $a1, $v0             
    la    $t0, buffer_convert
    addiu $t0, $t0, 11
    sub   $a2, $t0, $a1
    li    $v0, 15
    move  $a0, $s6
    syscall

    move  $t2, $t7             
    addi  $t2, $t2, 4          
    addi  $t4, $t4, 1          
    blt   $t4, 100, item_loop

end_items:
    li    $v0, 15
    move  $a0, $s6
    la    $a1, newline
    li    $a2, 1
    syscall

    addi  $t3, $t3, 1
    j     bin_loop

close_and_return:
    li    $v0, 16
    move  $a0, $s6
    syscall
    j     start                

error_open_output:
    li    $v0, 4
    la    $a0, err_open_output
    syscall
    j     start                

#=============================== integer_to_string ===============================#
integer_to_string:
    la $t0, buffer_convert
    addiu $t0, $t0, 11         
    sb $zero, 0($t0)           
    beqz $a0, handle_zero

convert_loop:
    beqz $a0, reverse_string
    li $t1, 10
    div $a0, $t1
    mfhi $t2                   
    mflo $a0                   
    addi $t2, $t2, '0'
    addiu $t0, $t0, -1
    sb $t2, 0($t0)
    j convert_loop

handle_zero:
    addiu $t0, $t0, -1
    li $t2, '0'
    sb $t2, 0($t0)

reverse_string:
    move $v0, $t0              
    jr $ra

#=============================== Quit ===============================#
do_quit:
    j exit

#=============================== Error Handling ===============================#
error_open:
    li   $v0, 4
    la   $a0, err_open
    syscall
    j    exit

error_read:
    li   $v0, 4
    la   $a0, err_read
    syscall
    j    exit

exit:
    li   $v0, 10
    syscall

#=============================== init_bins ===============================#
init_bins:
    li    $t0, 0
    la    $t1, bin_count
    sw    $t0, ($t1)

    la    $t2, bin_capacity
    li    $t3, 100
    l.s   $f0, one
reset_caps:
    s.s   $f0, ($t2)
    addi  $t2, $t2, 4
    addi  $t3, $t3, -1
    bgtz  $t3, reset_caps

    la    $t2, bin_contents
    li    $t3, 10000             # Dynamic clearing for all 10000 words
    li    $t4, -1
reset_conts:
    sw    $t4, ($t2)
    addi  $t2, $t2, 4
    addi  $t3, $t3, -1
    bgtz  $t3, reset_conts

    jr    $ra