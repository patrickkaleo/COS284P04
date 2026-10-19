extern fopen
extern fclose
extern fgetc
extern ungetc
extern malloc
extern fscanf

; same layout as the C structs. endstruc makes State_size, Transition_size, DFA_size.
; State: int then a bool. bool is 1 byte, alignb 4 bumps the size to 8.
struc State
    .id resd 1
    .isAccepting resb 1
    alignb 4
endstruc

; from and to are ints, symbol is 1 char. size ends up 12.
struc Transition
    .from resd 1
    .to resd 1
    .symbol resb 1
    alignb 4
endstruc

; two pointers (8 each), then the 3 ints packed at 16, 20 and 24.
; ints only need 4-byte alignment so there is no hole between them.
; alignb 8 at the end makes the whole thing 32, which is what C uses.
struc DFA
    .states resq 1
    .transitions resq 1
    .numStates resd 1
    .numTransitions resd 1
    .startState resd 1
    alignb 8
endstruc

section .bss
    id_buff resd 1
    seperator resb 1

section .data
    rm db "r", 0
    dcd_fmt db "%d,%d", 0       ; line 1, eg 3,6
    ic_fmt db "%d%c", 0         ; a number then the comma or the newline
    t_fmt db "%d,%d,%c", 0      ; from,to,symbol

section .text
    global readDfa

; DFA* readDfa(const char* filename)
; filename arrives in rdi. return the pointer in rax, or 0 if the file wont open.
readDfa:
    ; rbx/r12/r13/r14 stay alive across calls, so they have to be saved.
    ; after 4 pushes the stack is still off by 8, so one more sub lines it up for the call.
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 8

    ; fopen(filename, "r"). rdi is still the filename.
    lea rsi, [rel rm]
    call fopen
    test rax, rax
    jz .null
    mov r12, rax                ; keep the FILE* in r12, calls will trash rax

    ; block for the DFA itself. 32 bytes.
    mov edi, DFA_size
    call malloc
    test rax, rax
    jz .close_null
    mov rbx, rax                ; rbx is the DFA for the rest of the function

    ; line 1 goes straight into the struct. rdx/rcx are addresses, not the numbers.
    ; fscanf writes numStates and numTransitions there.
    mov rdi, r12
    lea rsi, [rel dcd_fmt]
    mov rdx, rbx
    add rdx, DFA.numStates
    mov rcx, rbx
    add rcx, DFA.numTransitions
    xor eax, eax                ; fscanf is variadic, al = number of float args, we have none
    call fscanf
    cmp eax, 2                  ; it returns how many values it actually stored
    jne .close_null

    ; spec says the start state is always 0. it is not a line in the file.
    mov dword [rbx + DFA.startState], 0

    ; numStates is a 4 byte int. eax, not rax, or the load also pulls numTransitions.
    mov eax, dword [rbx + DFA.numStates]
    imul eax, State_size
    mov edi, eax
    call malloc
    test rax, rax
    jz .close_null
    mov [rbx + DFA.states], rax

    mov eax, dword [rbx + DFA.numTransitions]
    imul eax, Transition_size
    mov edi, eax
    call malloc
    test rax, rax
    jz .close_null
    mov [rbx + DFA.transitions], rax

    ; line 2 is the state ids, one per state: 0,1,2
    mov r13, [rbx + DFA.states]
    mov r14d, dword [rbx + DFA.numStates]
    test r14d, r14d
    jz .accept_peek

.read_state:
    mov rdi, r12
    lea rsi, [rel ic_fmt]
    lea rdx, [rel id_buff]
    lea rcx, [rel seperator]    ; %c consumes the comma, or the newline on the last id
    xor eax, eax
    call fscanf
    cmp eax, 2
    jne .close_null

    mov eax, dword [id_buff]
    mov dword [r13 + State.id], eax
    mov byte [r13 + State.isAccepting], 0   ; accepting ids are the next line, so start at false
    add r13, State_size
    dec r14d
    jnz .read_state

; line 3 is the accepting ids. could be "0" or "0,3" or just a blank line.
.accept_peek:
    mov rdi, r12
    call fgetc
    cmp eax, 10                 ; '\n' means nothing on this line
    je .read_trans
    cmp eax, -1
    je .read_trans
    mov edi, eax
    mov rsi, r12
    call ungetc                 ; put the digit back so fscanf can read it

.accept_loop:
    mov rdi, r12
    lea rsi, [rel ic_fmt]
    lea rdx, [rel id_buff]
    lea rcx, [rel seperator]
    xor eax, eax
    call fscanf
    cmp eax, 2
    jne .read_trans

    ; id might not be the array index, so search for the state with that id
    mov eax, dword [id_buff]
    mov r13, [rbx + DFA.states]
    mov r14d, dword [rbx + DFA.numStates]

.find_state:
    test r14d, r14d
    jz .accept_step
    cmp dword [r13 + State.id], eax
    je .mark_state
    add r13, State_size
    dec r14d
    jmp .find_state

.mark_state:
    mov byte [r13 + State.isAccepting], 1

.accept_step:
    cmp byte [seperator], ','   ; comma means another id on this line
    je .accept_loop

; every line after that is one transition
.read_trans:
    mov r13, [rbx + DFA.transitions]
    mov r14d, dword [rbx + DFA.numTransitions]
    test r14d, r14d
    jz .done

.trans_loop:
    mov rdi, r12
    lea rsi, [rel t_fmt]
    mov rdx, r13                ; &from, offset 0
    mov rcx, r13
    add rcx, Transition.to
    mov r8, r13
    add r8, Transition.symbol   ; 5th arg goes in r8
    xor eax, eax
    call fscanf
    cmp eax, 3
    jne .close_null

    add r13, Transition_size
    dec r14d
    jnz .trans_loop

.done:
    mov rdi, r12
    call fclose
    mov rax, rbx                ; return the DFA*
    jmp .leave

.close_null:
    mov rdi, r12
    call fclose

.null:
    xor eax, eax                ; NULL

.leave:
    add rsp, 8
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
