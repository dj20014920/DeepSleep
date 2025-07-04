tell application "Xcode"
    activate
    delay 1
    
    -- File > Add Files to Project 메뉴 클릭
    tell application "System Events"
        tell process "Xcode"
            -- File 메뉴 클릭
            click menu bar item "File" of menu bar 1
            delay 0.5
            
            -- Add Files 메뉴 항목 찾기
            try
                click menu item 2 of menu 1 of menu bar item "File" of menu bar 1
                delay 1
                
                -- 파일 선택 다이얼로그에서 DeepSleepApp 폴더로 이동
                tell window 1
                    -- 프로젝트 루트 디렉토리가 열렸다고 가정하고 DeepSleepApp 폴더로 이동
                    keystroke "g" using {command down, shift down}
                    delay 0.5
                    
                    -- DeepSleepApp 경로 입력
                    keystroke "DeepSleepApp"
                    delay 0.5
                    
                    keystroke return
                    delay 1
                    
                    -- 모든 Swift 파일 선택 (Cmd+A)
                    keystroke "a" using command down
                    delay 0.5
                    
                    -- Add 버튼 클릭
                    click button "Add"
                end tell
                
            on error
                display dialog "Could not find Add Files menu item"
            end try
        end tell
    end tell
end tell
