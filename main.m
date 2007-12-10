//
//  main.m
//  login-tool
//
//  Created by Wincent Colaiuta on 1 Mar 2004.
//  Copyright 2004-2007 Wincent Colaiuta.

#import <Foundation/Foundation.h>
#import <unistd.h>                  /* for getopt() */
#import "SystemEvents.h"

// WOCommon headers
#import "WOCommon/WOConvenienceMacros.h"
#import "WOCommon/WOLoginItem.h"
#import "WOCommon/WOLoginItemList.h"

void usage(void)
{
    printf("Usage:      login-tool [-r name] [-a path [-H]]\n"
           "            login-tool -h\n"
           " -h         : show usage\n"
           " -r name    : remove items matching name\n"
           " -a path    : add item with path\n"
           " -H         : set 'hide' attribute on added item\n"
           " -l         : list items\n");
}

void printLoginItem(WOLoginItem *item)
{
    NSCParameterAssert(item != nil);
    NSCParameterAssert(item.name != nil);
    NSCParameterAssert(item.path != nil);

    printf("%s login item:\n"
           "  Name   : %s\n"
           "  Path   : %s\n"
           "  Hidden?: %s\n",
           item.global ? "Global" : "Session", [item.name UTF8String], [item.path UTF8String], item.hidden ? "YES" : "NO");
}

void listLoginItems(void)
{
    for (WOLoginItem *item in [WOLoginItemList globalLoginItems])
        printLoginItem(item);
    for (WOLoginItem *item in [WOLoginItemList sessionLoginItems])
        printLoginItem(item);
}

void printSuccess(BOOL success)
{
    printf(success ? "success\n" : "failure!\n");
}

int main (int argc, const char * argv[])
{
    NSAutoreleasePool   *pool       = [[NSAutoreleasePool alloc] init];
    char                *remove     = NULL;
    char                *add        = NULL;
    BOOL                hide        = NO;
    int                 status      = EXIT_SUCCESS;
    int                 ret         = getopt(argc, (char * const *)argv, "hlr:a:H");

    // TODO: accept multiple args eg. multiple -r multiple -a etc
    while (ret != -1)
    {
        switch (ret)
        {
            case 'h':       // show help
                usage();
                goto cleanup;

            case 'l':       // list items
                listLoginItems();
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
    if (argc - optind > 0)      // non-option arguments not allowed
    {
        status = EXIT_FAILURE;
        usage();
        goto cleanup;
    }

    if ((add == NULL) && hide)  // can't specify -H without -a
    {
        status = EXIT_FAILURE;
        usage();
        goto cleanup;
    }

    if (remove != NULL)
    {
        printf("Removing login items with name: %s... ", remove);
        printSuccess([[WOLoginItemList sessionLoginItems] removeItemsWithName:[NSString stringWithCString:remove]]);
    }

    if (add != NULL)
    {
        if (hide)
            printf("Adding login item with path: %s (hide on launch)... ", add);
        else
            printf("Adding login item with path: %s (show on launch)... ", add);

        // remove item if it already exists
        NSString *path = [NSString stringWithUTF8String:add];
        [[WOLoginItemList sessionLoginItems] removeItemWithPath:path];

        WOLoginItem *item = [WOLoginItem loginItemWithName:nil path:path hidden:hide global:NO];
        printSuccess([[WOLoginItemList sessionLoginItems] addItem:item]);
    }

cleanup:
    WO_FREE(remove);
    WO_FREE(add);
    [pool drain];
    return status;
}
