/*
 * _CPAutocompleteMenu.j
 * AppKit
 *
 * Created by Alexander Ljungberg on May 10, 2012.
 * Copyright 2012, Alexander Ljungberg. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

@import <Foundation/CPObject.j>

@import "CPTextField.j"
@import "_CPMenuWindow.j"


/*!
    An "autocomplete" menu displayed by a text field.
*/
@implementation _CPAutocompleteMenu : CPObject
{
    CPTextField     textField @accessors;
    CPArray         contentArray @accessors;

    CPWindow        _menuWindow;
    CPScrollView    scrollView;
    CPTableView     tableView;

    CPTimer         _showCompletionsTimer;
}

- (id)initWithTextField:(CPTextField)aTextField
{
    if (self = [super init])
    {
        textField = aTextField;

        _menuWindow = [[CPWindow alloc] initWithContentRect:CGRectMake(0, 0, 100, 100) styleMask:CPBorderlessWindowMask];

        [_menuWindow setLevel:CPPopUpMenuWindowLevel];
        [_menuWindow setHasShadow:YES];
        [_menuWindow setShadowStyle:CPMenuWindowShadowStyle];
        [_menuWindow setAcceptsMouseMovedEvents:NO];
        [_menuWindow setBackgroundColor:[_CPMenuWindow backgroundColorForBackgroundStyle:_CPMenuWindowPopUpBackgroundStyle]];

        var contentView = [_menuWindow contentView];

        scrollView = [[CPScrollView alloc] initWithFrame:CGRectMakeZero()];
        [scrollView setAutohidesScrollers:YES];
        [scrollView setHasHorizontalScroller:NO];
        [contentView addSubview:scrollView];

        tableView = [[CPTableView alloc] initWithFrame:CPRectMakeZero()];

        var tableColumn = [CPTableColumn new];
        [tableColumn setResizingMask:CPTableColumnAutoresizingMask];
        [tableView addTableColumn:tableColumn];

        [tableView setDataSource:self];
        [tableView setDelegate:self];
        [tableView setAllowsMultipleSelection:NO];
        [tableView setHeaderView:nil];
        [tableView setCornerView:nil];
        [tableView setRowHeight:30.0];
        [tableView setGridStyleMask:CPTableViewSolidHorizontalGridLineMask];
        [tableView setBackgroundColor:[CPColor clearColor]];
        [tableView setGridColor:[CPColor colorWithRed:242.0 / 255.0 green:243.0 / 255.0 blue:245.0 / 255.0 alpha:1.0]];

        [scrollView setDocumentView:tableView];
    }

    return self;
}

/*!
    Set an array of strings to use as the available completions.
*/
- (void)setContentArray:(CPArray)anArray
{
    contentArray = anArray;

    [tableView reloadData];
}

- (void)setIndexOfSelectedItem:(int)anIndex
{
    [tableView selectRowIndexes:[CPIndexSet indexSetWithIndex:anIndex] byExtendingSelection:NO];
    [tableView scrollRowToVisible:anIndex];
}

- (int)indexOfSelectedItem
{
    return [tableView selectedRow];
}

- (CPString)selectedItem
{
    return contentArray ? contentArray[[tableView selectedRow]] : nil;
}

- (void)layoutSubviews
{
    // TODO
    /*
    The autocompletion menu should be underneath the word/text being autocompleted. It should at least be wide enough to
    fit the widest
    option but no wider than the width of the text field. It might stick out on the right side, so that if the edited text
    is on the right of the text field the menu might extend a full text field width more into space on the right
    side. It should not stick out outside of the screen. The height should be the smallest possible to fit all options
    or at most ~307px (based on Cocoa). If the options don't fit horizontally they should be truncated with an ellipsis.
    */

    var frame = [textField frame];

    // Correctly size the tableview
    // FIXME Horizontal scrolling will not work because we are not actually looking at the content to set the width for the table column
    [[[tableView tableColumns] firstObject] setWidth:[[scrollView contentView] frame].size.width];

    // Manually sizeToFit because CPTableView's sizeToFit doesn't work properly
    var frameOrigin = [textField convertPoint:[textField bounds].origin toView:nil],
        newFrame = CGRectMake(frameOrigin.x, frameOrigin.y + frame.size.height, CPRectGetWidth([textField bounds]), 92.0);
    [_menuWindow setFrame:[_menuWindow frameRectForContentRect:newFrame]];
    [scrollView setFrame:CGRectInset([[_menuWindow contentView] bounds], 1.0, 1.0)];
}

- (void)_showCompletions:(CPTimer)timer
{
    var indexOfSelectedItem = [self indexOfSelectedItem];

    [self setContentArray:[textField _completionsForSubstring:[textField _inputElement].value indexOfToken:0 indexOfSelectedItem:indexOfSelectedItem]];

    // TODO Support indexOfSelectedItem. Always 0 right now.
    [self setIndexOfSelectedItem:indexOfSelectedItem];

    [textField setThemeState:CPThemeStateAutocompleting];
    [_menuWindow orderFront:self];

    [self layoutSubviews];
}

- (void)_delayedShowCompletions
{
    var completionDelay = 0.5;

    if ([textField respondsToSelector:@selector(completionDelay)])
        completionDelay = [textField completionDelay];

    _showCompletionsTimer = [CPTimer scheduledTimerWithTimeInterval:completionDelay
                                                             target:self
                                                           selector:@selector(_showCompletions:)
                                                           userInfo:nil
                                                            repeats:NO];
}

- (void)_hideCompletions
{
    [_showCompletionsTimer invalidate];
    _showCompletionsTimer = nil;

    [textField unsetThemeState:CPThemeStateAutocompleting];
    [_menuWindow orderOut:self];
    [self layoutSubviews];
}

- (void)selectNext
{
    var index = [self indexOfSelectedItem] + 1;

    if (index >= [contentArray count])
        return;

    [self setIndexOfSelectedItem:index];
}

- (void)selectPrevious
{
    var index = [self indexOfSelectedItem] - 1;

    if (index < 0)
        return;

    [self setIndexOfSelectedItem:index];
}

- (int)numberOfRowsInTableView:(CPTableView)tableView
{
    return [contentArray count];
}

- (void)tableView:(CPTableView)tableView objectValueForTableColumn:(CPTableColumn)tableColumn row:(int)row
{
    return [contentArray objectAtIndex:row];
}

- (void)tableViewSelectionDidChange:(CPNotification)notification
{
    // FIXME
    // make sure a mouse click in the tableview doesn't steal first responder state
    window.setTimeout(function()
    {
        [[textField window] makeFirstResponder:textField];
    }, 2.0);
}

@end
