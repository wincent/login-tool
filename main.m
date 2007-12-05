//
//  main.m
//  login-tool
//
//  Created by Wincent Colaiuta on 1 Mar 2004.
//  Copyright 2004-2007 Wincent Colaiuta.

// limitations:
// - ignores arguments specified after options have been parsed with getopt

#import <Foundation/Foundation.h>
#import <unistd.h>                  /* for getopt() */
#import "SystemEvents.h"

// helper method: add item to login items
void addLoginItem(NSString *path, BOOL hideOnLaunch);

// helper method: remove item from login items: always operates on full path
void removeLoginItemWithPath(NSString *path);

// helper method: remove item from login items: use with caution
void removeLoginItemWithName(NSString *name);

// helper method: does the actual work of removing login items
void removeLoginItemWithNameOrPath(NSString *name, NSString *path);

// show usage instructions
void usage(void);

// list currently defined login items
void list(void);

int main (int argc, const char * argv[])
{
    NSAutoreleasePool   *pool       = [[NSAutoreleasePool alloc] init];
    char                *remove     = NULL;
    char                *add        = NULL;
    BOOL                hide        = NO;
    int                 status      = EXIT_SUCCESS;
    int                 ret         = getopt(argc, (char * const *)argv, "hlr:a:H");
    while (ret != -1)
    {        
        switch (ret)
        {
            case 'h':       // show help
                usage();
                goto cleanup;

            case 'l':       // list items
                list();
                break;

            case 'r':       // remove item (filename only)
                remove = strdup(optarg);
                if (remove == NULL) return 1;
                break;
                
            case 'a':       // add item (full path)
                add = strdup(optarg);
                if (add == NULL) return 1;
                break;
                
            case 'H':       // set "Hide" attribute for added item
                hide = YES;
                break;
                
            case '?':       // unrecognized option or missing argument
            default:
                status = EXIT_FAILURE;
                usage();
                goto cleanup;
        }
       
        ret = getopt(argc, (char * const *)argv, "hr:a:H"); // get next option
    }
    
    if ((add == NULL) && hide)  // can't specify -H without -a
    {
        status = EXIT_FAILURE;
        usage();
        goto cleanup;
    }
        
    if (remove != NULL)
    {
        printf("Removing login item with name: %s\n", remove);
        removeLoginItemWithName([NSString stringWithCString:remove]);   
    }
    
    if (add != NULL)
    {
        if (hide)
            printf("Adding login item with path: %s (hide on launch)\n", add);
        else
            printf("Adding login item with path: %s (show on launch)\n", add);

        addLoginItem([NSString stringWithCString:add], hide);
    }
    
cleanup:
    if (remove != NULL) free(remove);
    if (add != NULL)    free(add);
    
    [pool drain];
    return status;
}

// show usage instructions
void usage(void)
{
    printf("Usage:      login-tool [-r item] [-a path [-H]]\n"
           "            login-tool -h\n"
           " -h         : show usage\n"
           " -r item    : remove item\n"
           " -a path    : add item (full path)\n"
           " -H         : set Hide attribute on added item\n"
           " -l         : list items\n");
}

SystemEventsApplication *system_events(void)
{
    static SystemEventsApplication *systemEvents = nil;
    if (!systemEvents)
        systemEvents = [SBApplication applicationWithBundleIdentifier:@"com.apple.systemevents"];
    return systemEvents;
}

void list(void)
{
    SystemEventsApplication *sys = system_events();
    NSArray *items = [[sys loginItems] arrayByApplyingSelector:@selector(properties)];
    for (NSDictionary *properties in items)
    {
        NSString *info = [NSString stringWithFormat:
                          @"Name     : %@\n"
                          @"  Kind   : %@\n"
                          @"  Path   : %@\n"
                          @"  Hidden?: %s\n",
                          [properties objectForKey:@"name"],
                          [properties objectForKey:@"kind"],
                          [properties objectForKey:@"path"],
                          [[properties objectForKey:@"hidden"] boolValue] ? "YES" : "NO"];
        printf([info UTF8String]);
    }
}

// helper method: add item to login items
void addLoginItem(NSString *path, BOOL hideOnLaunch)
{
    // if configuration file is malformed, could get here without a path
    if (!path) return;
    
    // remove item if it already exists
    removeLoginItemWithPath(path);
    
    // prepare dictionary for adding
    NSDictionary *loginItem = [NSDictionary dictionaryWithObjectsAndKeys:
            path,                                   @"Path",
            [NSNumber numberWithBool:hideOnLaunch], @"Hide", nil];
    
    // now try to add it
    NSUserDefaults      *defs       = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *loginDict  = [[defs persistentDomainForName:@"loginwindow"] mutableCopy];
    
    if (!loginDict) // no loginwindow.plist: create one from scratch
        loginDict = [NSMutableDictionary dictionaryWithCapacity:1];
    
    NSMutableArray *items = [[loginDict objectForKey:@"AutoLaunchedApplicationDictionary"] mutableCopy];
    
    if (!items)     // no items array: create one from scratch
        items = [NSMutableArray arrayWithCapacity:1];
    
    // put object at end of list
    [items insertObject:loginItem atIndex:[items count]];

    // plug list back into loginwindow dictionary
    [loginDict setObject:items forKey:@"AutoLaunchedApplicationDictionary"];

    // flush to disk
    [defs removePersistentDomainForName:@"loginwindow"];
    [defs setPersistentDomain:loginDict forName:@"loginwindow"];
    [defs synchronize];
}

// helper method: remove item from login items: always operates on full path
void removeLoginItemWithPath(NSString *path)
{
    // this code factored out for ease of maintenance
    removeLoginItemWithNameOrPath(nil, path);
}

// helper method: remove item from login items: use with caution
void removeLoginItemWithName(NSString *name)
{
    // this code factored out for ease of maintenance
    removeLoginItemWithNameOrPath(name, nil);
}

// helper method: does the actual work of removing login items
void removeLoginItemWithNameOrPath(NSString *name, NSString *path)
{
    SystemEventsApplication *sys = system_events();
    NSMutableArray *deleteable = [NSMutableArray array];
    SBElementArray *items = [sys loginItems];
    if ([items count] == 0) return;
    for (SystemEventsLoginItem *item in items)
    {
        NSString *comparePath = [item path];

        // test against path if defined + test against name if defined
        if ((path && ([path isEqualToString:comparePath])) ||
            (name && ([name isEqualToString:[comparePath lastPathComponent]])))
            // can't delete while iterating; will do in a separate pass
            [deleteable addObject:item];
    }
    for (SystemEventsLoginItem *item in deleteable)
    {
        [item delete];
    }
}
