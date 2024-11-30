#include <stdio.h>
#include <unistd.h>
#include <stdbool.h>
#include <string.h>
#include <sys/wait.h>
#include <stdlib.h>

#define MAXLEN 260

// 32220062 컴퓨터공학과 강우주가 직접 만든 코드임


// help 명령어
bool myshell_help(){
    printf("help : 모르는 명령어를 알려드리는 콜입니다.\n");
    printf("exit : 쉘에서 나갑니다.\n");
    printf("ls : 현 디렉토리내의 파일을 보여줍니다.\n");
    printf("cd : 다른 디랙토리로 이동합니다. 해당 명령어의 경우 \" cd [이동하고자 하는 디렉토리] \" 형식이 필요합니다.\n");
    return true;
}

// 입력받은 명령어를 토큰화 하는 함수
int tokenize(char *buf,char *delims,char *tokens[],int maxTokens){
    
    // char *buf : 토큰화 하려는 문자열
    // char *delims : 잘라내고자 하는 문자열을 자를 기준 문자열을 입력 ex) ' ' , ','
    
    int tokenCount = 0;
    char *token = strtok(buf, delims);
    // strtok 함수를 이용해 문자열을 구분자 ( delims ) 로 분리하여 tokens 배열에 저장
    while (token != NULL && tokenCount < maxTokens) {
           tokens[tokenCount++] = token; // token-strtok를 기준으로 뺴낸 문자열을 tokens에 저장
           token = strtok(NULL, delims);  // 다음 토큰을 찾음
    }
    return tokenCount;  // 총 토큰 개수 반환
}

bool run(char* line){
    
    char *tokens[10];  // 최대 10개의 토큰을 저장할 수 있도록 배열 생성
    char delims[] = " \t\n";  // 공백과 탭을 구분자로 사용
    int tokenCount;
    int pipeLocation = -1; // 파이프에 사용할 int 인덱스
    
    line[strcspn(line, "\n")] = 0;  // 개행 문자 제거
    
    
     // printf("입력된 명령어: %s\n", line);  // 입력된 명령어 출력 -> 디버깅용으로 사용했음
    
    tokenCount = tokenize(line, delims, tokens, sizeof(tokens) / sizeof(char*));
    // 마지막 인자에서 byte 단위로 결과가 도출되기 떄문에 sizeof(char*)로 나누어주었음.
    // ex) sizeof(tokens) -> 10 * 8 (char* 의 사이즈가 8바이트) = 80
    
    // 토큰화된 결과 출력 ( 디버깅 용도로 사용했음 )
    /*    for (int i = 0; i < tokenCount; i++) {
            printf("tokens[%d] = %s\n", i, tokens[i]);
        }
    */
    if(tokenCount==0){
        return true; // 다시 명령어를 사용하도록 한다.
    }
    
    if(strcmp(tokens[0],"exit")==0){
        return false; // 첫 인자에 exit이 들어갈 경우 루프 탈출
    }
    
    if(strcmp(tokens[0],"quit")==0){
        return false;
    }
    
    if(strcmp(tokens[0],"help")==0){
        return myshell_help(); // 첫 인자에 help가 들어간 경우 도움말을 보여주는 실행
    }
    // cd 명령어가 안되는 오류 수정
    // chdir 함수를 이용해서 디렉토리 변경하는 구현
    if (strcmp(tokens[0], "cd") == 0) {
        // cd 명령어 처리
        if (tokenCount < 2) {
            fprintf(stderr, "cd 실패");
        } else {
            if (chdir(tokens[1]) != 0) { // chdir 함수로 디렉토리 변경
                perror("디렉토리 변경 실패");
            }
        }
        return true; // cd 처리를 마치고 true를 반환해 루프 지속
    }
    
    // 파이프의 위치를 찾는 메소드
    for(int i=0;i<tokenCount;i++){
        if(strcmp(tokens[i],"|")==0){
            pipeLocation = i;
            break;
        }
    }
    
    
    // Pipe 명령어
    // 1st. 파이프 키워드 기준으로 명령어 2개로 나누기
    // 2nd. 파이프 실행하기 -> lecture 5 코드 참고
    
    if(pipeLocation != -1){
        //1st. 파이프 키워드 기준으로 명령어 2개로 나누기
        char *firstWord[pipeLocation+1]; // 파이프를 기준으로 첫 번째 명령어 분배
        char *secondWord[tokenCount - pipeLocation]; // 파이프를 기준으로 두 번째 명령어 분배 -> 전체 명령어 갯수 - 파이프 위치
        
        for(int i = 0 ; i < pipeLocation ; i++){ // 첫 번째 명령어를 firstWord 배열에 옮기기
            firstWord[i] = tokens[i];
        }
        firstWord[pipeLocation] = NULL; // 문자열 배열 마지막에 NULL 설정 -> 안해주면 제대로 작동 x
        
        int p = 0 ; // 두 번쨰 명령어를 넣어줄 때 , 인덱스를 맞춰주기 위해서 초기화
        for(int s = pipeLocation + 1 ; s < tokenCount ; s ++ , p++ ){
            secondWord[p] = tokens[s];
        }
        secondWord[tokenCount - pipeLocation - 1] = NULL; // 첫번째와 마찬가지로 마지막에 NULL 설정
        
        
        // 2nd. 파이프 실행하기
        pid_t pid;
        int fd[2];
        
        pipe(fd);
        pid = fork();
        
        // 첫 번째 자식 프로세스 - > 첫번째 명령어
        if(pid==0){
            close(fd[0]); // 읽기 파이프 닫기
            dup2(fd[1],STDOUT_FILENO); // 표준 출력을 파이프의 쓰기로 리다이렉션 -> 교수님이 말씀하신 dup2()로 리다이렉션 설명 참고
            execvp(firstWord[0],firstWord); // 첫 번째 명령어 실행
            perror("execvp() 실패!"); // 오류 메시지
            _exit(1);
            
        } else {
            // 부모 프로세스
            waitpid(pid, NULL, 0); // 첫 번째 자식 프로세스가 끝날 때까지 대기
                    
            pid = fork(); // 두 번째 자식 프로세스 생성
            if (pid == 0) {
            // 두 번째 자식 프로세스
            close(fd[1]); // 쓰기 파이프 닫기
            dup2(fd[0], STDIN_FILENO); // 표준 입력을 파이프의 읽기 쪽으로 리디렉션
            execvp(secondWord[0], secondWord); // 두 번째 명령어 실행
            perror("execvp() 실패"); // 오류 메시지
            _exit(1);
            } else {
                // 부모 프로세스
                close(fd[0]); // 부모에서 파이프 읽기 끝 닫기
                close(fd[1]); // 부모에서 파이프 쓰기 끝 닫기
                waitpid(pid, NULL, 0); // 두 번째 자식 프로세스가 끝날 때까지 대기
            }
        }
    }
    
    pid_t pid=fork(); // 자식 프로세스 생성하기 -> chapte.5 PPT 참조
    if(pid<0){
        perror("자식 프로세스 생성 실패");
        return true;
    } else if( pid == 0){
        tokens[tokenCount] = NULL;  // execvp()의 인자 배열 마지막에 NULL 추가
        execvp(tokens[0],tokens); // 외부 명령어는 exec함수로 실행
        perror("execvp()실패");
        _exit(1); // 프로세스를 즉시 종료
    } else {
        // 부모 프로세스에서 자식 프로세스가 끝날 때까지 기다림
        waitpid(pid, NULL, 0);
    }
    
    return true;
    
}


int main() {
    char line[1024];
    char dirName[1024]; // getcwd 함수를 사용하기 위해 받는 배열
    
    while(1){
        printf("%s $",getcwd(dirName,MAXLEN));
        // char *getcwd(char *buf,size_t size) ->
        // buf : 현재 디렉토리의 경로를 저장할 버퍼 주소
        // size : 버퍼의 크기
        fgets(line,sizeof(line)-1,stdin);
        if(run(line)==false){
            break;
        }
    }
}

