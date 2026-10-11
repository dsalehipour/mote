from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
source = (root/'Mote.m').read_text()
out = Path(__file__).resolve().parent/'build'
out.mkdir(parents=True, exist_ok=True)

def end_brace(text, start):
    depth=0; i=start
    while i < len(text):
        match=re.match(r'//[^\n]*|/\*[\s\S]*?\*/|@?"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'',text[i:])
        if match: i+=len(match[0]); continue
        if text[i]=='{': depth+=1
        if text[i]=='}':
            depth-=1
            if depth==0: return i+1
        i+=1
    raise ValueError('Unclosed brace')

classes=[]
for match in re.finditer(r'@implementation (\w+)\n([\s\S]*?)@end', source):
    name,body=match.groups()
    base=re.search(r'@interface '+name+r'\s*:\s*(\w+)',source)[1]
    methods=[]; pos=0
    while m:=re.search(r'-\s*\(([^)]+)\)\s*([^{}]+?)\s*\{', body[pos:]):
        begin=pos+m.start(); opening=pos+m.end()-1; end=end_brace(body,opening)
        ret,sig=m.groups(); args=re.findall(r'(\w+):\s*\(([^)]+)\)\s*(\w+)',sig)
        selector=''.join(a[0]+':' for a in args) if args else sig.strip()
        methods.append(dict(ret=ret, signature=sig.strip(), args=args, selector=selector,
                            body=body[opening:end], name=name+'_'+selector.replace(':','_')))
        pos=end
    classes.append(dict(name=name,base=base,methods=methods))

def encoding(t):
    known = {'void':'v','BOOL':'B','NSRect':'{CGRect={CGPoint=dd}{CGSize=dd}}','SEL':':','NSTimeInterval':'d'}
    if t in known: return known[t]
    if t == 'id' or re.fullmatch(r'(?:NS\w+|VN\w+|SC\w+|Mote\w*|Selection\w+)\s*\*', t.strip()): return '@'
    raise ValueError('Review the ABI encoding for new method type: '+t)

imports=source[:source.index('// No bundled')]
interfaces=[]; functions=[]; definitions=[]
for cls in classes:
    properties='\n@property NSImage *snapshot;\n@property (copy) void (^completion)(NSRect rect);' if cls['name']=='SelectionView' else ''
    declarations='\n'.join('- ('+m['ret']+')'+m['signature']+';' for m in cls['methods'])
    interfaces.append('@interface '+cls['name']+' : '+cls['base']+properties+'\n'+declarations+'\n@end')
    for m in cls['methods']:
        args=', '.join(t+' '+n for _,t,n in m['args'])
        body=m['body'].replace('self->selectionWindow','selectionWindow')
        body=re.sub(r'\[super (\w+):event\]',r'SuperEvent(self, "'+cls['base']+r'", _cmd, event)',body)
        if m['selector']=='selectSnapshot:screen:': body=body.replace('{','{\n    anchor = cursor = NSZeroPoint; selecting = NO;',1)
        functions.append('static '+m['ret']+' '+m['name']+'('+cls['name']+' *self, SEL _cmd'+(', '+args if args else '')+') '+body)
        types=encoding(m['ret'])+'@:'+''.join(encoding(t) for _,t,_ in m['args'])
        definitions.append('{"'+cls['name']+'", "'+cls['base']+'", "'+m['selector']+'", (IMP)'+m['name']+', "'+types+'"}')

globals=re.search(r'@interface Mote : NSObject \{([\s\S]*?)\n\}',source)[1]
globals='\n'.join('static '+line.strip() for line in globals.splitlines() if line.strip())
recognize=source[source.index('static NSUserDefaults'):source.index('@interface MoteButton')]
helpers=source[source.index('static OSStatus Hotkey'):source.index('@implementation Mote\n')]
main=source[source.index('int main('):].replace('        NSApplication *app =','        RegisterClasses();\n        NSApplication *app =')

runtime='''
#import <objc/runtime.h>
#import <objc/message.h>
#undef NSApp
#define NSApp ((NSApplication *)[MoteClass("NSApplication") sharedApplication])
static Class MoteClass(const char *name) { return objc_getClass(name); }
static NSPoint anchor, cursor;
static BOOL selecting;
static char snapshotKey, completionKey;
static NSImage *Snapshot(id self, SEL cmd) { return objc_getAssociatedObject(self, &snapshotKey); }
static void SetSnapshot(id self, SEL cmd, NSImage *image) { objc_setAssociatedObject(self, &snapshotKey, image, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
typedef void (^Completion)(NSRect);
static Completion GetCompletion(id self, SEL cmd) { return objc_getAssociatedObject(self, &completionKey); }
static void SetCompletion(id self, SEL cmd, Completion completion) { objc_setAssociatedObject(self, &completionKey, completion, OBJC_ASSOCIATION_COPY_NONATOMIC); }
static void SuperEvent(id self, const char *base, SEL selector, NSEvent *event) {
    struct objc_super super = { self, MoteClass(base) };
    ((void (*)(struct objc_super *, SEL, NSEvent *))objc_msgSendSuper)(&super, selector, event);
}
'''
definitions += [
    '{"SelectionView", "NSView", "snapshot", (IMP)Snapshot, "@@:"}',
    '{"SelectionView", "NSView", "setSnapshot:", (IMP)SetSnapshot, "v@:@"}',
    '{"SelectionView", "NSView", "completion", (IMP)GetCompletion, "@?@:"}',
    '{"SelectionView", "NSView", "setCompletion:", (IMP)SetCompletion, "v@:@?"}',
]
registration='''
static void RegisterClasses(void) {
    const struct { const char *name, *base, *selector; IMP implementation; const char *types; } methods[] = {
        '''+',\n        '.join(definitions)+'''
    };
    for (size_t i=0; i<sizeof(methods)/sizeof(methods[0]); i++) {
        Class cls = objc_getClass(methods[i].name);
        if (!cls) {
            cls=objc_allocateClassPair(objc_getClass(methods[i].base), methods[i].name, 0);
            if (!cls) abort();
            objc_registerClassPair(cls);
        }
        if (!class_addMethod(cls, sel_registerName(methods[i].selector), methods[i].implementation, methods[i].types)) abort();
    }
}
'''
result=imports+runtime+'\n'+'\n'.join(interfaces)+'\n'+globals+'\n'+recognize+helpers+'\n'+'\n'.join(functions)+registration+main

# Keep compiler-checked declarations while resolving receiver classes at launch.
class_names=set(re.findall(r'\b(?:NS|VN|SC)\w+(?=\.|\s+(?:alloc|new|[a-z]\w*:))',source)) | {c['name'] for c in classes}
class_names.update(re.findall(r"\[([A-Z]\w+)\s", source))
class_names.discard("NSApp")
for name in sorted(class_names,key=len,reverse=True):
    result=re.sub(r'\b'+name+r'\.class\b','MoteClass("'+name+'")',result)
    result=re.sub(r'\b'+name+r'\.(\w+)',lambda m:'[MoteClass("'+name+'") '+m[1]+']',result)
    result=re.sub(r'\['+name+r'\s','[MoteClass("'+name+'") ',result)
result = re.sub(r'\[MoteClass\("NSColor"\) (\w+)\]', r'((NSColor *)[MoteClass("NSColor") \1])', result)
result=result.replace('@[request]', '[MoteClass("NSArray") arrayWithObject:request]')
result=result.replace('@[stateURL]', '[MoteClass("NSArray") arrayWithObject:stateURL]')
result=result.replace('@(argv[2])', '[MoteClass("NSString") stringWithUTF8String:argv[2]]')
result=result.replace('@{NSFontAttributeName:[MoteClass("NSFont") systemFontOfSize:16], NSForegroundColorAttributeName:((NSColor *)[MoteClass("NSColor") whiteColor])}', '[MoteClass("NSDictionary") dictionaryWithObjects:(id[]){[MoteClass("NSFont") systemFontOfSize:16], ((NSColor *)[MoteClass("NSColor") whiteColor])} forKeys:(id[]){NSFontAttributeName, NSForegroundColorAttributeName} count:2]')
result=result.replace('@{NSFilePosixPermissions:@0700}', '[MoteClass("NSDictionary") dictionaryWithObject:@0700 forKey:NSFilePosixPermissions]')
result=re.sub(r'@\{NSLocalizedDescriptionKey:(@"[^"\n]+")\}', r'[MoteClass("NSDictionary") dictionaryWithObject:\1 forKey:NSLocalizedDescriptionKey]', result)
(out/'Mote.m').write_text(result)
print('Generated',len(classes),'classes and',len(definitions),'callbacks')
