#!/usr/bin/env python3
"""Regenerate the dependency-free Xcode project. Run from the repository root."""
from pathlib import Path
import hashlib
import plistlib

ROOT = Path(__file__).resolve().parent.parent
objects = {}
def uid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def add(object_name, isa, **props):
    key = uid(object_name)
    objects[key] = dict(isa=isa, **props)
    return key

def ref(path, kind):
    return add('file:'+path, 'PBXFileReference', lastKnownFileType=kind, path=path, sourceTree='<group>')

shared = sorted(str(p.relative_to(ROOT)) for folder in ['Shared', 'SkyStack', 'Pulse'] for p in (ROOT/folder).glob('*.swift'))
app_sources = sorted(str(p.relative_to(ROOT)) for p in (ROOT/'App').glob('*.swift'))
clip_sources = ['AppClip/AppClipRootView.swift', 'AppClip/LumiArcadeClipApp.swift']
files = shared + app_sources + clip_sources + ['Tests/SkyStackTests.swift', 'UITests/SkyStackUITests.swift']
refs = {p: ref(p, 'sourcecode.swift') for p in files}
configs = ['Shared/PrivacyInfo.xcprivacy', 'Configuration/Product.xcconfig', 'App/Info.plist', 'AppClip/Info.plist', 'App/App.entitlements', 'AppClip/AppClip.entitlements', 'README.md']
for p in configs: refs[p] = ref(p, 'text.xcconfig' if p.endswith('xcconfig') else 'text.plist.xml' if p.endswith(('plist', 'entitlements', 'xcprivacy')) else 'net.daringfireball.markdown')
refs['Shared/Assets.xcassets'] = ref('Shared/Assets.xcassets', 'folder.assetcatalog')
products = []
targets = []

def config_list(name, settings, base=False):
    cs=[]
    for mode in ['Debug','Release']:
        s=dict(settings)
        if name == 'project':
            s.update(SWIFT_OPTIMIZATION_LEVEL='-Onone' if mode=='Debug' else '-O',
                     SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG $(inherited)' if mode=='Debug' else '$(inherited)',
                     DEBUG_INFORMATION_FORMAT='dwarf' if mode=='Debug' else 'dwarf-with-dsym',
                     ENABLE_TESTABILITY='YES' if mode=='Debug' else 'NO')
        kw=dict(buildSettings=s, name=mode)
        if base: kw['baseConfigurationReference']=refs['Configuration/Product.xcconfig']
        cs.append(add('config:'+name+mode,'XCBuildConfiguration',**kw))
    return add('configs:'+name,'XCConfigurationList',buildConfigurations=cs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')

def target(name, source_paths, product_type, extension, settings, dependencies=None, extra_phases=None):
    product=add('product:'+name,'PBXFileReference',explicitFileType='wrapper.application' if extension=='app' else 'wrapper.cfbundle',includeInIndex=0,path=name+'.'+extension,sourceTree='BUILT_PRODUCTS_DIR')
    products.append(product)
    builds=[add('build:'+name+p,'PBXBuildFile',fileRef=refs[p]) for p in source_paths]
    phases=[add('sources:'+name,'PBXSourcesBuildPhase',buildActionMask=2147483647,files=builds,runOnlyForDeploymentPostprocessing=0),
            add('frameworks:'+name,'PBXFrameworksBuildPhase',buildActionMask=2147483647,files=[],runOnlyForDeploymentPostprocessing=0),
            add('resources:'+name,'PBXResourcesBuildPhase',buildActionMask=2147483647,files=[add('privacy:'+name,'PBXBuildFile',fileRef=refs['Shared/PrivacyInfo.xcprivacy']), add('assets:'+name,'PBXBuildFile',fileRef=refs['Shared/Assets.xcassets'])] if extension=='app' else [],runOnlyForDeploymentPostprocessing=0)]
    phases += extra_phases or []
    s=dict(PRODUCT_NAME='$(TARGET_NAME)',SWIFT_VERSION='5.0',CODE_SIGN_STYLE='Automatic',**settings)
    if extension == 'app': s['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
    t=add('target:'+name,'PBXNativeTarget',buildConfigurationList=config_list(name,s),buildPhases=phases,buildRules=[],dependencies=dependencies or [],name=name,productName=name,productReference=product,productType=product_type)
    targets.append(t)
    return t

clip=target('SkyStackClip', shared+clip_sources, 'com.apple.product-type.application.on-demand-install-capable','app',dict(PRODUCT_BUNDLE_IDENTIFIER='$(SKY_STACK_BUNDLE_ID).Clip',INFOPLIST_FILE='AppClip/Info.plist',CODE_SIGN_ENTITLEMENTS='AppClip/AppClip.entitlements',SKIP_INSTALL='YES'))
def dependency(name, target_id):
    proxy=add('proxy:'+name,'PBXContainerItemProxy',containerPortal=uid('project'),proxyType=1,remoteGlobalIDString=target_id,remoteInfo=name)
    return add('dep:'+name,'PBXTargetDependency',target=target_id,targetProxy=proxy)
embedbuild=add('embedclip','PBXBuildFile',fileRef=uid('product:SkyStackClip'),settings={'ATTRIBUTES':['RemoveHeadersOnCopy']})
embed=add('embedphase','PBXCopyFilesBuildPhase',buildActionMask=2147483647,dstPath='$(CONTENTS_FOLDER_PATH)/AppClips',dstSubfolderSpec=16,files=[embedbuild],name='Embed App Clips',runOnlyForDeploymentPostprocessing=0)
app=target('SkyStack', shared+app_sources,'com.apple.product-type.application','app',dict(PRODUCT_BUNDLE_IDENTIFIER='$(SKY_STACK_BUNDLE_ID)',INFOPLIST_FILE='App/Info.plist',CODE_SIGN_ENTITLEMENTS='App/App.entitlements'),[dependency('SkyStackClip',clip)],[embed])
tests=target('SkyStackTests',['Tests/SkyStackTests.swift'],'com.apple.product-type.bundle.unit-test','xctest',dict(PRODUCT_BUNDLE_IDENTIFIER='$(SKY_STACK_BUNDLE_ID).Tests',GENERATE_INFOPLIST_FILE='YES',TEST_HOST='$(BUILT_PRODUCTS_DIR)/SkyStack.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/SkyStack',BUNDLE_LOADER='$(TEST_HOST)'),[dependency('SkyStack',app)])
ui=target('SkyStackUITests',['UITests/SkyStackUITests.swift'],'com.apple.product-type.bundle.ui-testing','xctest',dict(PRODUCT_BUNDLE_IDENTIFIER='$(SKY_STACK_BUNDLE_ID).UITests',GENERATE_INFOPLIST_FILE='YES',TEST_TARGET_NAME='SkyStack'),[uid('dep:SkyStack')])
pg=add('products','PBXGroup',children=products,name='Products',sourceTree='<group>')
main=add('main','PBXGroup',children=list(refs.values())+[pg],sourceTree='<group>')
settings=dict(IPHONEOS_DEPLOYMENT_TARGET='17.0',SDKROOT='iphoneos',SUPPORTED_PLATFORMS='iphoneos iphonesimulator',TARGETED_DEVICE_FAMILY='1',CLANG_ENABLE_MODULES='YES',CLANG_ENABLE_OBJC_ARC='YES',SWIFT_EMIT_LOC_STRINGS='YES',ENABLE_USER_SCRIPT_SANDBOXING='YES',LD_RUNPATH_SEARCH_PATHS='$(inherited) @executable_path/Frameworks',ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS='YES')
add('project','PBXProject',attributes=dict(BuildIndependentTargetsInParallel='YES',LastUpgradeCheck='1630',TargetAttributes={app:dict(CreatedOnToolsVersion='16.3'),clip:dict(CreatedOnToolsVersion='16.3',SystemCapabilities={'com.apple.OnDemandInstallCapable':{'enabled':1}}),tests:dict(TestTargetID=app),ui:dict(TestTargetID=app)}),buildConfigurationList=config_list('project',settings,True),compatibilityVersion='Xcode 14.0',developmentRegion='en',hasScannedForEncodings=0,knownRegions=['en','Base'],mainGroup=main,productRefGroup=pg,projectDirPath='',projectRoot='',targets=targets)
# XML property lists are accepted by Xcode's project parser and avoid fragile quoting.
project=ROOT/'SkyStack.xcodeproj'
project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_bytes(plistlib.dumps(dict(archiveVersion='1',classes={},objectVersion='56',objects=objects,rootObject=uid('project')),sort_keys=False))

schemes=project/'xcshareddata'/'xcschemes'
schemes.mkdir(parents=True,exist_ok=True)
def buildref(name):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target:"+name)}" BuildableName="{name}.app" BlueprintName="{name}" ReferencedContainer="container:SkyStack.xcodeproj"/>'
scheme_specs = [
    ('SkyStack', 'SkyStack', None),
    ('SkyStackClip', 'SkyStackClip', 'https://play.lumiarcade.com/a/00025'),
]
for name, target_name, invocation_url in scheme_specs:
    testables=''
    if name=='SkyStack':
        for tn in ['SkyStackTests','SkyStackUITests']:
            testables += f'<TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target:"+tn)}" BuildableName="{tn}.xctest" BlueprintName="{tn}" ReferencedContainer="container:SkyStack.xcodeproj"/></TestableReference>'
    env=f'<EnvironmentVariables><EnvironmentVariable key="_XCAppClipURL" value="{invocation_url}" isEnabled="YES"/></EnvironmentVariables>' if invocation_url else ''
    (schemes/(name+'.xcscheme')).write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1630" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{buildref(target_name)}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables>{testables}</Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildref(target_name)}</BuildableProductRunnable>{env}</LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildref(target_name)}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
