; same offsets as task1. this file is assembled on its own, so the strucs have to be here too.
struc State
    .id resd 1
    .isAccepting resb 1
    alignb 4
endstruc

struc Transition
    .from resd 1
    .to resd 1
    .symbol resb 1
    alignb 4
endstruc

struc DFA
    .states resq 1
    .transitions resq 1
    .numStates resd 1
    .numTransitions resd 1
    .startState resd 1
    alignb 8
endstruc

section .text
    global simulateDfa

; bool simulateDfa(DFA* dfa, const char* input)
; rdi = dfa, rsi = the string. return 1 or 0 in rax.
simulateDfa:
    test rdi, rdi
    jz .reject
    test rsi, rsi
    jz .reject

    ; r10 is the state we are in. start from whatever the DFA says, normally 0.
    movsxd r10, dword [rdi + DFA.startState]

.next_char:
    movzx r9d, byte [rsi]
    test r9b, r9b
    jz .check_accept            ; hit the terminating 0, string is done
    inc rsi

    ; scan the transition list for from == current and symbol == this char
    mov ecx, dword [rdi + DFA.numTransitions]
    mov r8, [rdi + DFA.transitions]

.find_trans:
    test ecx, ecx
    jz .reject                  ; no transition for this char
    cmp dword [r8 + Transition.from], r10d
    jne .skip_trans
    cmp byte [r8 + Transition.symbol], r9b
    je .take_trans

.skip_trans:
    add r8, Transition_size
    dec ecx
    jmp .find_trans

.take_trans:
    movsxd r10, dword [r8 + Transition.to]
    jmp .next_char

; string finished. accepting depends on the state we landed in, not on the char.
.check_accept:
    mov ecx, dword [rdi + DFA.numStates]
    mov r8, [rdi + DFA.states]

.find_state:
    test ecx, ecx
    jz .reject
    cmp dword [r8 + State.id], r10d
    je .is_accepting
    add r8, State_size
    dec ecx
    jmp .find_state

.is_accepting:
    movzx eax, byte [r8 + State.isAccepting]    ; 1 if that state accepts, else 0
    ret

.reject:
    xor eax, eax
    ret
