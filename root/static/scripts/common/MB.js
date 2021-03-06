/* Copyright (C) 2009 Oliver Charles

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

'use strict';

// Namespaces
window.MB = {
    // Classes, common controls used throughout MusicBrainz
    Control: {},

    // Utility functions
    utility: {},

    // Hold translated text strings
    text: {},

    // Hold constants
    constants: {},

    // Holds data where localStorage isn't supported
    store: {},

    // Deprecated reference needed by knockout templates
    i18n: require('./i18n.js')
};

MB.constants.VARTIST_GID = '89ad4ac3-39f7-470e-963a-56509c546377';
MB.constants.VARTIST_NAME = 'Various Artists';

MB.constants.SERIES_ORDERING_TYPE_AUTOMATIC = 1;
MB.constants.SERIES_ORDERING_TYPE_MANUAL = 2;

MB.constants.PART_OF_SERIES_LINK_TYPES_BY_ENTITY = {
    event: "707d947d-9563-328a-9a7d-0c5b9c3a9791",
    recording: "ea6f0698-6782-30d6-b16d-293081b66774",
    release: "3fa29f01-8e13-3e49-9b0a-ad212aa2f81d",
    release_group: "01018437-91d8-36b9-bf89-3f885d53b5bd",
    work: "b0d44366-cdf0-3acb-bee6-0f65a77a6ef0"
};

MB.constants.PART_OF_SERIES_LINK_TYPES = _.values(MB.constants.PART_OF_SERIES_LINK_TYPES_BY_ENTITY);

MB.constants.SERIES_ORDERING_ATTRIBUTE = "a59c5830-5ec7-38fe-9a21-c7ea54f6650a";

// orchestrator, orchestra performed, conductor, concertmaster
MB.constants.PROBABLY_CLASSICAL_LINK_TYPES = [40, 45, 46, 150, 151, 300, 759, 760]

MB.constants.VIDEO_ATTRIBUTE_ID = 582;
MB.constants.VIDEO_ATTRIBUTE_GID = "112054d5-e706-4dd8-99ea-09aabee36cd6";

MB.constants.ENTITIES = [
  'area',
  'artist',
  'editor',
  'event',
  'instrument',
  'label',
  'place',
  'release',
  'release-group',
  'recording',
  'series',
  'work'
];

MB.constants.MAX_LENGTH_DIFFERENCE = 10500;
MB.constants.MIN_NAME_SIMILARITY = 0.75;

MB.constants.MAX_RECENT_ENTITIES = 10;

// https://bugzilla.mozilla.org/show_bug.cgi?id=365772
try {
    MB.hasLocalStorage = !!window.localStorage;
    MB.hasSessionStorage = !!window.sessionStorage;
} catch (e) {
    MB.hasLocalStorage = false;
    MB.hasSessionStorage = false;
}

MB.localStorage = function (name, value) {
    if (arguments.length > 1) {
        var inLocalStorage = false;

        if (MB.hasLocalStorage) {
            try {
                localStorage[name] = value;
                inLocalStorage = true;
            } catch (e) {
                // NS_ERROR_DOM_QUOTA_REACHED
                // NS_ERROR_FILE_NO_DEVICE_SPACE
            }
        }
        if (!inLocalStorage) {
            MB.store[name] = value;
        }
    } else {
        var storedValue;

        if (MB.hasLocalStorage) {
            try {
                storedValue = localStorage[name];
            } catch (e) {
                // NS_ERROR_FILE_CORRUPTED?
            }

            // localStorage.hasOwnProperty doesn't exist in IE8 and is outright
            // broken in Opera (at least the Presto versions). Source:
            // https://shanetomlinson.com/2012/localstorage-bugs-inconsistent-removeitem-delete/

            if (storedValue !== undefined) {
                return storedValue;
            }
        }
        return MB.store[name];
    }
};
