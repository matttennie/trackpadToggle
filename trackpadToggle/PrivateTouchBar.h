/*
 * trackpadToggle - Touch Bar trackpad toggle
 * Copyright (C) 2026
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#ifndef PrivateTouchBar_h
#define PrivateTouchBar_h

#import <AppKit/AppKit.h>

// DFRFoundation C functions for Control Strip integration
extern void DFRElementSetControlStripPresenceForIdentifier(NSTouchBarItemIdentifier _Nonnull identifier, BOOL present);
extern void DFRSystemModalShowsCloseBoxWhenFrontMost(BOOL show);

// Private NSTouchBarItem methods for system tray
@interface NSTouchBarItem (Private)
+ (void)addSystemTrayItem:(NSTouchBarItem * _Nonnull)item;
+ (void)removeSystemTrayItem:(NSTouchBarItem * _Nonnull)item;
@end

// Private NSTouchBar methods for modal presentation
@interface NSTouchBar (Private)
+ (void)presentSystemModalTouchBar:(NSTouchBar * _Nullable)touchBar
            systemTrayItemIdentifier:(NSTouchBarItemIdentifier _Nonnull)identifier;
+ (void)dismissSystemModalTouchBar:(NSTouchBar * _Nullable)touchBar;
+ (void)minimizeSystemModalTouchBar:(NSTouchBar * _Nullable)touchBar;
@end

#endif /* PrivateTouchBar_h */
