#!/usr/bin/env python3
"""
Xcode Project Auto-Sync Script
자동으로 파일 변경사항을 감지하고 Xcode 프로젝트를 업데이트합니다.
"""

import os
import sys
import time
import subprocess
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import plistlib
import uuid

class XcodeProjectHandler(FileSystemEventHandler):
    def __init__(self, project_path):
        self.project_path = project_path
        self.pbxproj_path = os.path.join(project_path, "project.pbxproj")
        self.last_update = 0
        self.pending_changes = set()
        
    def on_created(self, event):
        if not event.is_directory and self._should_track(event.src_path):
            print(f"File created: {event.src_path}")
            self.pending_changes.add(('create', event.src_path))
            self._schedule_update()
            
    def on_deleted(self, event):
        if not event.is_directory and self._should_track(event.src_path):
            print(f"File deleted: {event.src_path}")
            self.pending_changes.add(('delete', event.src_path))
            self._schedule_update()
            
    def on_moved(self, event):
        if not event.is_directory and self._should_track(event.src_path):
            print(f"File moved: {event.src_path} -> {event.dest_path}")
            self.pending_changes.add(('delete', event.src_path))
            self.pending_changes.add(('create', event.dest_path))
            self._schedule_update()
    
    def _should_track(self, path):
        # 추적할 파일 확장자
        tracked_extensions = {'.swift', '.m', '.mm', '.h', '.c', '.cpp', 
                            '.storyboard', '.xib', '.plist', '.json', 
                            '.xcassets', '.metal', '.strings'}
        
        # 무시할 경로
        ignored_paths = {'.git', '.build', 'DerivedData', '.swiftpm', 
                        'xcuserdata', '.DS_Store', '.idea', '.vscode'}
        
        path_parts = path.split(os.sep)
        
        # 무시할 경로 체크
        for ignored in ignored_paths:
            if ignored in path_parts:
                return False
                
        # 확장자 체크
        _, ext = os.path.splitext(path)
        return ext.lower() in tracked_extensions
    
    def _schedule_update(self):
        # 변경사항을 모아서 1초 후에 한번에 처리
        current_time = time.time()
        if current_time - self.last_update > 1:
            self.last_update = current_time
            # 1초 후에 업데이트 실행
            subprocess.Popen([sys.executable, __file__, '--update', self.project_path])
            
    def refresh_xcode(self):
        """Xcode에 변경사항을 알림"""
        # AppleScript를 사용해 Xcode 새로고침
        script = '''
        tell application "Xcode"
            if (count of windows) > 0 then
                tell front window
                    set currentDoc to document
                    if currentDoc is not missing value then
                        -- 프로젝트 네비게이터 새로고침
                        tell application "System Events"
                            tell process "Xcode"
                                -- Cmd+1로 프로젝트 네비게이터 선택
                                keystroke "1" using command down
                                delay 0.1
                                -- 포커스 이동으로 새로고침 유도
                                key code 48 -- Tab
                                delay 0.1
                                key code 48 using shift down -- Shift+Tab
                            end tell
                        end tell
                    end if
                end tell
            end if
        end tell
        '''
        
        try:
            subprocess.run(['osascript', '-e', script], capture_output=True)
            print("Xcode refreshed")
        except Exception as e:
            print(f"Failed to refresh Xcode: {e}")

def watch_project(project_path):
    """프로젝트 디렉토리 감시 시작"""
    project_dir = os.path.dirname(project_path)
    
    event_handler = XcodeProjectHandler(project_path)
    observer = Observer()
    observer.schedule(event_handler, project_dir, recursive=True)
    observer.start()
    
    print(f"Watching for changes in: {project_dir}")
    print("Press Ctrl+C to stop...")
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
        print("\nStopping file watcher...")
    observer.join()

def main():
    if len(sys.argv) < 2:
        # 현재 디렉토리에서 Xcode 프로젝트 찾기
        for item in os.listdir('.'):
            if item.endswith('.xcodeproj'):
                project_path = os.path.abspath(item)
                break
        else:
            print("Error: No Xcode project found in current directory")
            print("Usage: python xcode_sync.py [path/to/project.xcodeproj]")
            sys.exit(1)
    else:
        if sys.argv[1] == '--update' and len(sys.argv) > 2:
            # 업데이트 모드
            handler = XcodeProjectHandler(sys.argv[2])
            handler.refresh_xcode()
            return
        else:
            project_path = os.path.abspath(sys.argv[1])
    
    if not os.path.exists(project_path):
        print(f"Error: Project not found: {project_path}")
        sys.exit(1)
        
    watch_project(project_path)

if __name__ == "__main__":
    main()
