#!/usr/bin/env python3

import os
import re
import uuid

def add_file_to_project(file_path, project_pbxproj_path):
    """프로젝트 파일에 새로운 파일 참조 추가"""
    
    # UUID 생성
    file_ref_uuid = ''.join(str(uuid.uuid4()).split('-')).upper()[:24]
    build_file_uuid = ''.join(str(uuid.uuid4()).split('-')).upper()[:24]
    
    # 파일명 추출
    filename = os.path.basename(file_path)
    
    with open(project_pbxproj_path, 'r') as f:
        content = f.read()
    
    # 1. PBXBuildFile 섹션에 추가
    build_file_pattern = r'(/\* Begin PBXBuildFile section \*/.*?/\* End PBXBuildFile section \*/)'
    build_file_match = re.search(build_file_pattern, content, re.DOTALL)
    
    if build_file_match:
        build_file_section = build_file_match.group(1)
        new_build_file = f"\t\t{build_file_uuid} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* {filename} */; }};"
        
        # 마지막 항목 뒤에 추가
        lines = build_file_section.split('\n')
        lines.insert(-1, new_build_file)
        new_build_file_section = '\n'.join(lines)
        content = content.replace(build_file_section, new_build_file_section)
    
    # 2. PBXFileReference 섹션에 추가
    file_ref_pattern = r'(/\* Begin PBXFileReference section \*/.*?/\* End PBXFileReference section \*/)'
    file_ref_match = re.search(file_ref_pattern, content, re.DOTALL)
    
    if file_ref_match:
        file_ref_section = file_ref_match.group(1)
        new_file_ref = f"\t\t{file_ref_uuid} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};"
        
        lines = file_ref_section.split('\n')
        lines.insert(-1, new_file_ref)
        new_file_ref_section = '\n'.join(lines)
        content = content.replace(file_ref_section, new_file_ref_section)
    
    # 3. DeepSleepApp 그룹에 파일 추가
    group_pattern = r'(570538FADACE15DD630375AA /\* DeepSleepApp \*/ = \{[^}]+children = \([^)]+)\);'
    group_match = re.search(group_pattern, content, re.DOTALL)
    
    if group_match:
        group_section = group_match.group(1)
        new_file_entry = f"\t\t\t\t{file_ref_uuid} /* {filename} */,"
        
        # 알파벳 순서로 삽입 위치 찾기
        lines = group_section.split('\n')
        insert_index = len(lines) - 1
        
        for i, line in enumerate(lines):
            if '/*' in line and '*/' in line:
                existing_filename = re.search(r'/\* ([^*]+) \*/', line)
                if existing_filename and existing_filename.group(1) > filename:
                    insert_index = i
                    break
        
        lines.insert(insert_index, new_file_entry)
        new_group_section = '\n'.join(lines)
        content = content.replace(group_section, new_group_section)
    
    # 4. PBXSourcesBuildPhase에 추가
    sources_pattern = r'(files = \([^)]+)\);'
    sources_matches = re.finditer(sources_pattern, content, re.DOTALL)
    
    for match in sources_matches:
        if 'isa = PBXSourcesBuildPhase' in content[max(0, match.start()-500):match.start()]:
            sources_section = match.group(1)
            new_source_entry = f"\t\t\t\t{build_file_uuid} /* {filename} in Sources */,"
            
            lines = sources_section.split('\n')
            lines.insert(-1, new_source_entry)
            new_sources_section = '\n'.join(lines)
            content = content.replace(sources_section, new_sources_section)
            break
    
    # 파일에 쓰기
    with open(project_pbxproj_path, 'w') as f:
        f.write(content)
    
    print(f"✅ Added {filename} to project")

def main():
    import sys
    project_pbxproj = "DeepSleep.xcodeproj/project.pbxproj"
    
    # 인수로 파일이 지정되었는지 확인
    if len(sys.argv) > 1:
        files_to_add = sys.argv[1:]
    else:
        # 기본 누락 파일 목록
        files_to_add = [
            "DeepSleepApp/ViewController+EmotionSelector.swift",
            "DeepSleepApp/ViewController+PlaybackControls.swift", 
            "DeepSleepApp/ViewController+SliderControls.swift",
            "DeepSleepApp/Models/TodoItem.swift"
        ]
        
        # 추가로 프로젝트에 없는 Swift 파일들을 자동 감지
        print("🔍 Scanning for missing Swift files...")
        
        # 모든 Swift 파일 찾기
        all_swift_files = []
        for root, dirs, files in os.walk("DeepSleepApp"):
            for file in files:
                if file.endswith('.swift'):
                    file_path = os.path.join(root, file)
                    all_swift_files.append(file_path)
        
        # 프로젝트에 없는 파일들 찾기
        with open(project_pbxproj, 'r') as f:
            project_content = f.read()
        
        missing_files = []
        for file_path in all_swift_files:
            filename = os.path.basename(file_path)
            if filename not in project_content:
                missing_files.append(file_path)
        
        if missing_files:
            print(f"📄 Found {len(missing_files)} missing files:")
            for f in missing_files:
                print(f"   - {f}")
            files_to_add.extend(missing_files)
        else:
            print("✅ No missing files found")
    
    if not files_to_add:
        print("ℹ️  No files to add")
        return
    
    # 프로젝트 파일 백업
    os.system(f"cp '{project_pbxproj}' '{project_pbxproj}.backup'")
    print("📁 Project file backed up")
    
    added_count = 0
    for file_path in files_to_add:
        if os.path.exists(file_path):
            add_file_to_project(file_path, project_pbxproj)
            added_count += 1
        else:
            print(f"⚠️  File not found: {file_path}")
    
    if added_count > 0:
        print(f"\n🎉 Added {added_count} files to project!")
        print("💡 Next steps:")
        print("   1. Refresh Xcode: Cmd+Option+U")
        print("   2. Or run: xcode-refresh")
        print("   3. Clean build if needed: Cmd+Shift+K")
    else:
        print("\nℹ️  No files were added")
    
    print(f"\n🔧 If something goes wrong, restore from backup:")
    print(f"   cp '{project_pbxproj}.backup' '{project_pbxproj}'")

if __name__ == "__main__":
    main()
