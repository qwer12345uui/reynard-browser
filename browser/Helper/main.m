//
//  main.m
//  Reynard
//
//  Created by Minh Ton on 20/2/26.
//

// https://github.com/LiveContainer/LiveContainer/blob/382fca93abfa01e08b7df6601e6238840aaf3a4a/LiveProcess/main.m

#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <os/log.h>
#include <stdlib.h>

static BOOL allowXPCDecoderClass(id receiver, SEL selector, Class allowedClass,
                                 id key, BOOL allowingInvocations) {
  return YES;
}

__attribute__((used, visibility("default"))) int NSExtensionMain(int argc,
                                                                 char *argv[]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
  Class decoderClass = NSClassFromString(@"NSXPCDecoder");
  Method validationMethod = class_getInstanceMethod(
      decoderClass,
      @selector(_validateAllowedClass:forKey:allowingInvocations:));
  if (validationMethod != NULL) {
    method_setImplementation(validationMethod, (IMP)allowXPCDecoderClass);
  }
#pragma clang diagnostic pop

  int (*origNSExtensionMain)(int, char **) =
      (int (*)(int, char **))dlsym(RTLD_NEXT, "NSExtensionMain");
  if (origNSExtensionMain == NULL || origNSExtensionMain == NSExtensionMain) {
    os_log_error(OS_LOG_DEFAULT,
                 "Unable to resolve the system NSExtensionMain entry point");
    return EXIT_FAILURE;
  }
  return origNSExtensionMain(argc, argv);
}
