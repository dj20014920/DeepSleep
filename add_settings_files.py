#!/usr/bin/env python3
"""
Xcode 프로젝트에 설정 관련 파일들을 추가하는 스크립트
"""

import uuid
import re

def generate_xcode_id():
    """Xcode에서 사용하는 24자리 ID 생성"""
    return str(uuid.uuid4()).replace('-', '').upper()[:24]

def add_files_to_project():
    """프로젝트 파일에 설정 관련 파일들 추가"""
    
    # 추가할 파일들
    files_to_add = [
        "SettingsViewController.swift",
        "SettingsSectionView.swift", 
        "UserSettingsModel.swift",
        "StubViewControllers.swift",
        "AIModelSelectionViewController.swift"
    ]
    
    # 각 파일에 대한 ID 생성
    file_ids = {}
    build_ids = {}
    
    for file in files_to_add:
        file_ids[file] = generate_xcode_id()
        build_ids[file] = generate_xcode_id()
    
    project_file = "/Users/dj20014920/Desktop/DeepSleep/DeepSleep.xcodeproj/project.pbxproj"
    
    # 프로젝트 파일 읽기
    with open(project_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # PBXBuildFile 섹션에 추가
    build_file_section = "/* Begin PBXBuildFile section */"
    build_file_additions = []
    
    for file in files_to_add:
        build_file_additions.append(
            f"\t\t{build_ids[file]} /* {file} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ids[file]} /* {file} */; }};"
        )
    
    # PBXFileReference 섹션에 추가할 내용
    file_ref_additions = []
    for file in files_to_add:
        file_ref_additions.append(
            f"\t\t{file_ids[file]} /* {file} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {file}; sourceTree = \"<group>\"; }};"
        )
    
    # Sources in Build Phases에 추가할 내용
    sources_additions = []
    for file in files_to_add:
        sources_additions.append(f"\t\t\t\t{build_ids[file]} /* {file} in Sources */,")
    
    # 파일 그룹에 추가할 내용
    group_additions = []
    for file in files_to_add:
        group_additions.append(f"\t\t\t\t{file_ids[file]} /* {file} */,")
    
    print("생성된 파일 ID들:")
    for file in files_to_add:
        print(f"{file}: {file_ids[file]} (build: {build_ids[file]})")
    
    # 실제 프로젝트 파일 수정은 수동으로 해야 함
    print("\n다음 내용들을 Xcode 프로젝트 파일에 수동으로 추가해야 합니다:")
    print("\n=== PBXBuildFile 섹션에 추가할 내용 ===")
    for addition in build_file_additions:
        print(addition)
    
    print("\n=== PBXFileReference 섹션에 추가할 내용 ===") 
    for addition in file_ref_additions:
        print(addition)
    
    print("\n=== Sources 빌드 페이즈에 추가할 내용 ===")
    for addition in sources_additions:
        print(addition)
        
    print("\n=== 파일 그룹에 추가할 내용 ===")
    for addition in group_additions:
        print(addition)

if __name__ == "__main__":
    add_files_to_project()