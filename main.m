//
//  main.m
//  login-tool
//
//  Created by Wincent Colaiuta on 1 Mar 2004.
//  Copyright 2004-2007 Wincent Colaiuta.

// limitations:
// - ignores arguments specified after options have been parsed with getopt

#import <Foundation/Foundation.h>

// for getopt
#include <unistd.h>

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

int main (int argc, const char * argv[])
{
    NSAutoreleasePool   *pool       = [[NSAutoreleasePool alloc] init];
    char                *remove     = NULL;
    char                *add        = NULL;
    BOOL                hide        = NO;
    int                 ret         = getopt(argc, (char * const *)argv, "hr:a:H");
    while (ret != -1)
    {        
        switch (ret)
        {
            case 'h':       // show help
                usage();
                goto cleanup;
                
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
                usage();
                goto cleanup;
        }
       
        ret = getopt(argc, (char * const *)argv, "hr:a:H"); // get next option
    }
    
    if ((add == NULL) && hide)  // can't specify -H without -a
    {
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
    
    [pool release];
    return EXIT_SUCCESS;
}

// show usage instructions
void usage(void)
{
    printf("Usage:      login-tool [-r item] [-a path [-H]]\n"
           "            login-tool -h\n"
           " -h         : show usage\n"
           " -r item    : remove item\n"
           " -a path    : add item (full path)\n"
           " -H         : set Hide attribute on added item\n");
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
    
    if (!loginDict)
        // no loginwindow.plist: create one from scratch
        loginDict = [[NSMutableDictionary alloc] initWithCapacity:1];
    
    NSMutableArray *items = [[loginDict objectForKey:@"AutoLaunchedApplicationDictionary"] mutableCopy];
    
    if (!items)
        // no items array: create one from scratch
        items = [[NSMutableArray alloc] initWithCapacity:1];
    
    // put object at end of list
    [items insertObject:loginItem atIndex:[items count]];

    // plug list back into loginwindow dictionary
    [loginDict setObject:items forKey:@"AutoLaunchedApplicationDictionary"];

    // flush to disk
    [defs removePersistentDomainForName:@"loginwindow"];
    [defs setPersistentDomain:loginDict forName:@"loginwindow"];
    [defs synchronize];
    
    [loginDict  release];
    [items      release];
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
    NSUserDefaults  *defs       = [NSUserDefaults standardUserDefaults];
    NSDictionary    *loginDict  = [defs persistentDomainForName:@"loginwindow"];
    
    if (!loginDict) return;     // not necessarily a fatal error
    
    // this is an array, although it's misleadingly labelled as a "Dictionary"
    NSMutableArray *items = [[loginDict objectForKey:@"AutoLaunchedApplicationDictionary"] mutableCopy];
        
    if (!items) return;         // again not necessarily a fatal error
    
    id object = nil;
    for (unsigned i = 0, max = [items count]; i < max; i++)   // scan the array for a matching entry
    {
        // note that object, path and/or name can be nil with no ill effects
        object = [items objectAtIndex:i];
        if (!object) continue;
        
        // extract this separately for code readability
        NSString *comparePath = [object objectForKey:@"Path"];
        if (!comparePath) continue;
            
        // test against path if defined + test again name if defined    
        if ((path && ([comparePath isEqualToString:path])) ||
            (name && ([[comparePath lastPathComponent] isEqualToString:name])))
        {
            [items removeObjectAtIndex:i];  // found it: remove it
            
            NSMutableDictionary *updatedDict = [loginDict mutableCopy];
            [updatedDict setObject:items forKey:@"AutoLaunchedApplicationDictionary"];
            [defs removePersistentDomainForName:@"loginwindow"];
            [defs setPersistentDomain:updatedDict forName:@"loginwindow"];
            [defs synchronize];             // flush changes to disk
            
            [updatedDict release];  
            break;                          // no need to keep searching
        }
    }
    [items release];
}
