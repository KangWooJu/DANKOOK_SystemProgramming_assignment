.section .data
input_prompt:   .asciz "Input: \"<num1> <op> <num2>\"\n"  # 사용자에게 입력을 요청하는 메시지
invalid_input:  .asciz "Invalid input!\n"                 # 잘못된 입력 시 출력할 메시지
div_zero_error: .asciz "Error: Division by zero is not allowed!\n"  # 나누기 0 에러 메시지
result_msg:     .asciz "Result: "                         # 결과 출력 메시지
newline:        .asciz "\n"                               # 개행 문자

.section .bss
input_buffer:   .space 64        # 입력을 받을 버퍼 공간 64바이트 할당
num1:           .long 0          # 첫 번째 숫자 저장 공간
num2:           .long 0          # 두 번째 숫자 저장 공간
operator:       .byte 0          # 연산자 저장 공간 (예: +, -, *, /)
result_buffer:  .space 64        # 결과 문자열 버퍼 (64바이트 할당)

.section .text
.globl main
.globl input_Parsing
.globl calculate
.globl print_result
.globl remove_newline
.globl invalid_input_handler

main:
.loop:
    # 사용자 입력 안내 메시지 출력
    movl $4, %eax                # syscall 번호 (sys_write) -> 화면에 메시지를 출력하기 위한 시스템 호출
    movl $1, %ebx                # 파일 디스크립터 (stdout) -> 표준 출력
    movl $input_prompt, %ecx     # 메시지 주소
    movl $31, %edx               # 메시지 길이
    int $0x80                    # 시스템 콜 호출

    # 사용자 입력 받기
    movl $3, %eax                # syscall 번호 (sys_read) -> 사용자로부터 입력을 받기 위한 시스템 호출
    movl $0, %ebx                # 파일 디스크립터 (stdin) -> 표준 입력
    movl $input_buffer, %ecx     # 입력 버퍼 주소
    movl $64, %edx               # 최대 읽기 길이
    int $0x80                    # 시스템 콜 호출

    # 입력값에서 '\n' 제거
    call remove_newline

    # 입력값 파싱
    movl $input_buffer, %esi     # 입력 버퍼 주소를 %esi에 저장
    call input_Parsing           # 입력 파싱 함수 호출
    testl %eax, %eax             # 파싱 함수에서 반환값 확인
    jz invalid_input_handler     # 실패 시 잘못된 입력 처리기로 이동

    # 계산 수행
    call calculate               # 계산 수행

    # 결과 출력
    call print_result            # 결과 출력

    # 계속 반복
    jmp .loop                    # 무한 루프 (계속 입력을 받기 위해)

# 입력값에서 줄바꿈 문자 '\n' 제거하는 함수
remove_newline:
    movl $input_buffer, %esi     # 입력 버퍼 시작 주소
remove_newline_loop:
    movzbl (%esi), %eax          # 현재 문자 로드
    cmpb $'\n', %al              # 줄바꿈 문자인지 확인
    je replace_null              # 줄바꿈이면 NULL로 교체
    testb %al, %al               # NULL인지 확인
    je end_remove_newline        # NULL이면 종료
    incl %esi                    # 다음 문자로 이동
    jmp remove_newline_loop      # 반복

replace_null:
    movb $0, (%esi)              # NULL로 교체
end_remove_newline:
    ret                           # 함수 종료

# 입력값 파싱 함수 (숫자와 연산자 파싱)
input_Parsing:
    call parse_digit             # 첫 번째 숫자 파싱
    movl %eax, num1              # 첫 번째 숫자를 num1에 저장

    movzbl (%esi), %eax          # 연산자 로드 (8비트 확장)
    movb %al, operator           # 연산자를 operator에 저장
    cmpb $'+', %al
    je valid_operator            # '+'일 경우 유효 연산자 처리
    cmpb $'-', %al
    je valid_operator            # '-'일 경우 유효 연산자 처리
    cmpb $'*', %al
    je valid_operator            # '*'일 경우 유효 연산자 처리
    cmpb $'/', %al
    je valid_operator            # '/'일 경우 유효 연산자 처리

    movl $0, %eax                # 실패 반환 값 (잘못된 연산자)
    ret                           # 함수 종료

# 유효한 연산자 처리 함수
valid_operator:
    addl $1, %esi                # 연산자 이후로 이동
valid_operator_loop:
    movzbl (%esi), %eax          # 현재 문자를 로드
    cmpb $' ', %al               # 공백인지 확인
    je skip_space                # 공백이면 다음 문자로 이동
    jmp parse_second_digit       # 공백이 아니면 숫자 파싱으로 이동

skip_space:
    incl %esi                    # 다음 문자로 이동
    jmp valid_operator_loop      # 다시 루프

# 두 번째 숫자 파싱
parse_second_digit:
    call parse_digit             # 두 번째 숫자 파싱
    movl %eax, num2              # 두 번째 숫자를 num2에 저장
    movl $1, %eax                # 성공 반환 값
    ret                           # 함수 종료

# 숫자 파싱 함수 (문자 -> 숫자로 변환)
parse_digit:
    movzbl (%esi), %eax          # 입력에서 첫 번째 문자 로드
    cmpb $'0', %al               # 숫자인지 확인 ,
    jb not_a_digit               # '0'보다 작으면 숫자가 아님
    cmpb $'9', %al
    ja not_a_digit               # '9'보다 크면 숫자가 아님

    subb $'0', %al               # 아스키코드 숫자를 정수로 변환
    incl %esi                    # 다음 문자로 이동
    ret                           # 함수 종료

not_a_digit:
    movl $0, %eax                # 실패 시 0 반환
    ret                           # 함수 종료

# 계산 수행 함수
calculate:
    movzbl operator, %eax        # 연산자 로드
    cmpb $'+', %al
    je do_add                    # 덧셈 처리
    cmpb $'-', %al
    je do_sub                    # 뺄셈 처리
    cmpb $'*', %al
    je do_mul                    # 곱셈 처리
    cmpb $'/', %al
    je do_div                    # 나눗셈 처리

    # 잘못된 연산자 처리
    movl $1, %ebx
    movl $1, %eax
    int $0x80                     # 종료

do_add:
    movl num1, %eax              # 첫 번째 숫자 로드
    addl num2, %eax              # 두 번째 숫자 더하기
    ret

do_sub:
    movl num1, %eax              # 첫 번째 숫자 로드
    subl num2, %eax              # 두 번째 숫자 빼기
    ret

do_mul:
    movl num1, %eax              # 첫 번째 숫자 로드
    imull num2, %eax             # 두 번째 숫자 곱하기
    ret

do_div:
    movl num2, %ecx              # 두 번째 숫자 로드
    testl %ecx, %ecx             # 나누는 수가 0인지 확인
    jz div_zero_handler          # 0이면 에러 처리
    movl num1, %eax              # 첫 번째 숫자 로드
    cltd                         # 부호 확장
    idivl %ecx                   # 나눗셈 수행
    ret

div_zero_handler:
    movl $4, %eax                # syscall 번호 (sys_write)
    movl $1, %ebx                # 파일 디스크립터 (stdout)
    movl $div_zero_error, %ecx   # 에러 메시지 주소
    movl $38, %edx               # 메시지 길이
    int $0x80                     # 에러 메시지 출력
    movl $2, %ebx                # 종료 코드 2
    movl $1, %eax                # syscall 번호 (sys_exit)
    int $0x80                     # 프로그램 종료

# 결과 출력 함수
print_result:
    pushl %eax                    # 결과값 저장
    movl $result_msg, %ecx        # "Result: " 메시지 로드
    movl $4, %eax                 # syscall 번호 (sys_write)
    movl $1, %ebx                 # 파일 디스크립터 (stdout)
    movl $8, %edx                 # 메시지 길이
    int $0x80                     # 메시지 출력

    popl %eax                     # 결과값 복구
    movl $result_buffer, %edi     # 결과를 저장할 버퍼 주소
    call itoa                     # 결과를 문자열로 변환

    movl $4, %eax                 # syscall 번호 (sys_write)
    movl $1, %ebx                 # 파일 디스크립터 (stdout)
    movl %edi, %ecx               # 변환된 결과 문자열 주소
    movl $64, %edx                # 최대 길이
    int $0x80                     # 결과 문자열 출력

    movl $newline, %ecx           # 개행 문자 출력
    movl $4, %eax
    movl $1, %ebx
    movl $1, %edx
    int $0x80
    ret

# 숫자 -> 문자열 변환 함수 ( itoa 함수 : 정수를 10진수 문자열로 변환 하는 함수)
itoa:
    xorl %ecx, %ecx               # ECX를 0으로 초기화 (자리수 추적용 변수)
    movl %eax, %ebx               # EAX를 EBX에 복사 (원래의 숫자 값 저장, 계산 중 변경 방지)
    movl $result_buffer, %edi     # 결과 문자열을 저장할 버퍼 주소를 EDI에 저장

    cmpl $0, %eax                 # 숫자가 0인지 확인
    jne itoa_process              # 0이 아니면 변환 과정 진행
    movb $'0', (%edi)             # 0이면 문자열 "0"을 버퍼에 저장
    incl %edi                     # EDI 포인터를 하나 증가시켜서 버퍼에서 다음 위치로 이동
    ret                           # 함수 종료

itoa_process:
    movl $10, %ecx                # 나누기 기준 값으로 10을 설정 (10진수로 변환)
itoa_loop:
    xorl %edx, %edx               # EDX를 0으로 초기화 (나머지를 저장할 공간)
    divl %ecx                     # EAX를 10으로 나눠서 몫은 EAX, 나머지는 EDX에 저장
    addb $'0', %dl                # 나머지를 아스키코드의 문자로 변환
    decl %edi                     # EDI 포인터를 하나 감소시켜서 버퍼에 역순으로 저장
    movb %dl, (%edi)              # 변환된 문자를 버퍼에 저장
    testl %eax, %eax              # EAX(몫)가 0인지 확인
    jne itoa_loop                 # 몫이 0이 아니면 반복 (숫자 자리수가 남아 있을 경우)
    ret                           # 몫이 0이 되면 숫자 변환이 완료되었으므로 종료

# 잘못된 입력 처리
invalid_input_handler:
    movl $4, %eax                 # syscall 번호 (sys_write)
    movl $1, %ebx                 # 파일 디스크립터 (stdout)
    movl $invalid_input, %ecx     # "Invalid input!" 메시지 주소
    movl $15, %edx                # 메시지 길이
    int $0x80                     # 시스템 콜 호출

    movl $1, %ebx                 # 종료 코드 1
    movl $1, %eax                 # syscall 번호 (sys_exit)
    int $0x80                     # 프로그램 종료

