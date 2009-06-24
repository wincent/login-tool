// main.m
// login-tool
//
// Copyright 2004-2009 Wincent Colaiuta. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

// system headers
#import <Foundation/Foundation.h>
#import <unistd.h>                  /* for getopt() */

// WOPublic headers
#import "WOPublic/WOConvenienceMacros.h"
#import "WOPublic/WOLoginItem.h"
#import "WOPublic/WOLoginItemList.h"

// other headers
#import "login-tool_Version.h"      /* make what(1) produce meaningful output */

void usage(void)
{
    printf("Usage:      login-tool -r name [-r name...]\n"
           "            login-tool -H -a path [-a path...]\n"
           "            login-tool [ -h | -l ]\n"
           " -h         : show usage\n"
           " -r         : remove item(s)\n"
           " -a         : add item(s)\n"
           " -H         : set 'hide' attribute on added item(s)\n"
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
    NSMutableArray      *remove     = [NSMutableArray array];
    NSMutableArray      *add        = [NSMutableArray array];
    char                *arg        = NULL;
    BOOL                hide        = NO;
    int                 status      = EXIT_SUCCESS;
    int                 ret         = getopt(argc, (char * const *)argv, "hlr:a:H");

    // TODO: accept multiple args eg. multiple -r multiple -a etc
    while (ret != -1)
    {
        WO_FREE(arg);
        switch (ret)
        {
            case 'h':       // show help
                usage();
                goto cleanup;

            case 'l':       // list items
                listLoginItems();
                break;

            case 'r':       // remove item (filename only)
                arg = strdup(optarg);
                if (arg == NULL)
                    return EXIT_FAILURE;
                [remove addObject:[NSString stringWithUTF8String:arg]];
                break;

            case 'a':       // add item (full path)
                arg = strdup(optarg);
                if (arg == NULL)
                    return EXIT_FAILURE;
                [add addObject:[NSString stringWithUTF8String:arg]];
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

    if ((add.count == 0) && hide)  // can't specify -H without -a
    {
        status = EXIT_FAILURE;
        usage();
        goto cleanup;
    }

    for (NSString *name in remove)
    {
        printf("Removing login items with name: %s... ", [name UTF8String]);
        printSuccess([[WOLoginItemList sessionLoginItems] removeItemsWithName:name]);
    }

    for (NSString *path in add)
    {
        printf("Adding login item with path: %s (%s on launch)... ", [path UTF8String], hide ? "hide" : "show");

        // remove item if it already exists
        [[WOLoginItemList sessionLoginItems] removeItemWithPath:path];

        WOLoginItem *item = [WOLoginItem loginItemWithName:nil path:path hidden:hide global:NO];
        printSuccess([[WOLoginItemList sessionLoginItems] addItem:item]);
    }

cleanup:
    WO_FREE(arg);
    [pool drain];
    return status;
}
