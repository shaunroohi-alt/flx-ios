#!/usr/bin/env python3
"""Generate a self-contained Xcode project using only Python's standard library."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parent.parent
project = root / 'FLX.xcodeproj'
project.mkdir(exist_ok=True)
objects = {}

def uid(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()

def q(value):
    return json.dumps(str(value))

def add(name, contents):
    key = uid(name)
    objects[key] = contents
    return key

def arr(values):
    return '(' + ', '.join(values) + ',)'

sources = sorted(list((root / 'FLX').rglob('*.swift')) + list((root / 'FLX').rglob('*.cpp')))
resources = [root/'FLX/Resources/Reference.txt', root/'FLX/PrivacyInfo.xcprivacy', root/'FLX/Assets.xcassets']
headers = sorted((root/'FLX').rglob('*.h')) + [root/'FLX/Info.plist']
refs, source_builds, resource_builds = [], [], []
types = {'.swift': 'sourcecode.swift', '.cpp': 'sourcecode.cpp.cpp', '.h': 'sourcecode.c.h', '.txt': 'text', '.plist': 'text.plist.xml', '.xcprivacy': 'text.xml', '.xcassets': 'folder.assetcatalog'}
for file in sources + resources + headers:
    path = file.relative_to(root).as_posix()
    ref = add('ref:'+path, f'isa = PBXFileReference; lastKnownFileType = {types[file.suffix]}; path = {q(path)}; sourceTree = "<group>";')
    refs.append(ref)
    if file in sources or file in resources:
        build = add('build:'+path, f'isa = PBXBuildFile; fileRef = {ref};')
        (source_builds if file in sources else resource_builds).append(build)
product = add('product','isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = FLX.app; sourceTree = BUILT_PRODUCTS_DIR;')
products = add('products',f'isa = PBXGroup; children = {arr([product])}; name = Products; sourceTree = "<group>";')
group = add('group',f'isa = PBXGroup; children = {arr(refs+[products])}; sourceTree = "<group>";')
src = add('sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {arr(source_builds)}; runOnlyForDeploymentPostprocessing = 0;')
res = add('resources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {arr(resource_builds)}; runOnlyForDeploymentPostprocessing = 0;')
framework = add('frameworks','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')

def config(name, settings):
    body = ' '.join(f'{key} = {q(value)};' for key, value in settings.items())
    return add(name, f'isa = XCBuildConfiguration; buildSettings = {{ {body} }}; name = {name.split(":")[-1]};')

project_settings = {
    'CLANG_ENABLE_MODULES':'YES', 'CLANG_ENABLE_OBJC_ARC':'YES',
    'CLANG_CXX_LANGUAGE_STANDARD':'c++17', 'CLANG_CXX_LIBRARY':'libc++',
    'IPHONEOS_DEPLOYMENT_TARGET':'17.0', 'SDKROOT':'iphoneos',
    'SWIFT_VERSION':'5.0', 'GCC_WARN_64_TO_32_BIT_CONVERSION':'YES',
}
target_settings = {
    'PRODUCT_NAME':'FLX', 'PRODUCT_BUNDLE_IDENTIFIER':'com.mpaudio.flx',
    'INFOPLIST_FILE':'FLX/Info.plist', 'GENERATE_INFOPLIST_FILE':'NO',
    'SWIFT_OBJC_BRIDGING_HEADER':'FLX/FLX-Bridging-Header.h',
    'TARGETED_DEVICE_FAMILY':'1,2', 'CODE_SIGN_STYLE':'Automatic',
    'SUPPORTED_PLATFORMS':'iphoneos iphonesimulator',
    'SUPPORTS_MACCATALYST':'NO', 'SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD':'NO',
    'ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon',
    'LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks',
}
for level, base in [('project',project_settings),('target',target_settings)]:
    cs = []
    for build in ['Debug','Release']:
        settings = dict(base)
        settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone' if build == 'Debug' else '-O'
        settings['GCC_OPTIMIZATION_LEVEL'] = '0' if build == 'Debug' else '3'
        if build == 'Debug': settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
        if build == 'Release': settings['DEBUG_INFORMATION_FORMAT'] = 'dwarf-with-dsym'
        cs.append(config(level+':'+build, settings))
    add(level+':configs',f'isa = XCConfigurationList; buildConfigurations = {arr(cs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target = add('target',f'isa = PBXNativeTarget; buildConfigurationList = {uid("target:configs")}; buildPhases = {arr([src,framework,res])}; buildRules = (); dependencies = (); name = FLX; productName = FLX; productReference = {product}; productType = "com.apple.product-type.application";')
main = add('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 1600; TargetAttributes = {{ {target} = {{ CreatedOnToolsVersion = 16.0; }}; }}; }}; buildConfigurationList = {uid("project:configs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {group}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = {arr([target])};')
text = '// !$*UTF8*$!\n{\n archiveVersion = 1; classes = {}; objectVersion = 56;\n objects = {\n'
text += '\n'.join(f'  {key} = {{ {body} }};' for key, body in objects.items())
text += f'\n }};\n rootObject = {main};\n}}\n'
(project/'project.pbxproj').write_text(text)
scheme = project/'xcshareddata/xcschemes/FLX.xcscheme'
scheme.parent.mkdir(parents=True, exist_ok=True)
reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="FLX.app" BlueprintName="FLX" ReferencedContainer="container:FLX.xcodeproj"/>'
scheme.write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"/>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/>
 <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print(f'Generated {project} with {len(sources)} source files.')
