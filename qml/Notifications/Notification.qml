/*
 * Copyright (C) 2013 Canonical, Ltd.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.0
import Ubuntu.Components 1.1
import Unity.Notifications 1.0
import QMenuModel 0.1
import Utils 0.1

import Ubuntu.Components.ListItems 0.1 as ListItem

Item {
    id: notification

    property alias iconSource: icon.fileSource
    property alias secondaryIconSource: secondaryIcon.source
    property alias summary: summaryLabel.text
    property alias body: bodyLabel.text
    property var actions
    property var notificationId
    property var type
    property var hints
    property var notification
    property color color
    property bool fullscreen
    property int maxHeight
    property int margins
    property Gradient greenGradient : Gradient {
        GradientStop { position: 0.0; color: "#39b44a" }
        GradientStop { position: 1.0; color: "#50be61" }
    }
    property Gradient darkgreyGradient: Gradient {
        GradientStop { position: 0.0; color: "#534e4b" }
        GradientStop { position: 1.0; color: "#5d5856" }
    }

    fullscreen: false
    objectName: "background"
    implicitHeight: type !== Notification.PlaceHolder ? (fullscreen ? maxHeight : contentColumn.height + contentColumn.spacing * 2) : 0

    color: Qt.rgba(0.132, 0.117, 0.109, 0.97)
    opacity: 0

    state: {
        var result = "";

        if (type == Notification.SnapDecision) {
            if (ListView.view.currentIndex == index) {
                result = "expanded";
            } else {
                if (ListView.view.count > 2) {
                    if (ListView.view.currentIndex == -1 && index == 1) {
                        result = "expanded";
                    } else {
                        result = "contracted";
                    }
                } else {
                    result = "expanded";
                }
            }
        }

        return result;
    }

    Behavior on height {
        id: normalHeightBehavior

        //enabled: menuItemFactory.progress == 1
        enabled: true
        SequentialAnimation {
            PauseAnimation {
                duration: UbuntuAnimation.SnapDuration
            }
            UbuntuNumberAnimation {
                duration: UbuntuAnimation.SnapDuration
            }
        }
    }

    states:[
        State {
            name: "contracted"
            PropertyChanges {target: notification; height: units.gu(8)}
        },
        State {
            name: "expanded"
            PropertyChanges {target: notification; height: implicitHeight}
        }
    ]

    clip: fullscreen ? false : true

    visible: type != Notification.PlaceHolder

    UbuntuShape {
        id: shapedBack

        visible: !fullscreen
        anchors {
            fill: parent
            leftMargin: notification.margins
            rightMargin: notification.margins
        }
        color: parent.color
        opacity: parent.opacity
        radius: "medium"
    }

    Rectangle {
        id: nonShapedBack

        visible: fullscreen
        anchors.fill: parent
        color: parent.color
        opacity: parent.opacity
    }

    Item {
        id: contents
        anchors.fill: fullscreen ? nonShapedBack : shapedBack

        UnityMenuModelPaths {
            id: paths

            source: hints["x-canonical-private-menu-model"]

            busNameHint: "busName"
            actionsHint: "actions"
            menuObjectPathHint: "menuPath"
        }

        UnityMenuModel {
            id: unityMenuModel

            busName: paths.busName
            actions: paths.actions
            menuObjectPath: paths.menuObjectPath
        }

        Behavior on implicitHeight {
            id: heightBehavior

            enabled: false
            UbuntuNumberAnimation {
                duration: UbuntuAnimation.SnapDuration
            }
        }

        // delay enabling height behavior until the add transition is complete
        onOpacityChanged: if (opacity == 1) heightBehavior.enabled = true

        MouseArea {
            id: interactiveArea

            anchors.fill: parent
            objectName: "interactiveArea"
            onClicked: {
                if (notification.type == Notification.Interactive) {
                    notification.notification.invokeAction(actionRepeater.itemAt(0).actionId)
                } else {
                    notificationList.currentIndex = index;
                }
            }
        }

        Column {
            id: contentColumn
            objectName: "contentColumn"

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: fullscreen ? 0 : spacing
            }

            spacing: units.gu(1)

            Row {
                id: topRow

                spacing: contentColumn.spacing
                anchors {
                    left: parent.left
                    right: parent.right
                }

                ShapedIcon {
                    id: icon

                    objectName: "icon"
                    width: units.gu(6)
                    height: units.gu(6)
                    shaped: notification.hints["x-canonical-non-shaped-icon"] == "true" ? false : true
                    visible: iconSource !== undefined && iconSource != ""
               }

               Image {
                   id: secondaryIcon

                   objectName: "secondaryIcon"
                   width: units.gu(2)
                   height: units.gu(2)
                   visible: source !== undefined && source != ""
                   fillMode: Image.PreserveAspectCrop
               }

                Column {
                    id: labelColumn
                    width: parent.width - x

                    anchors.verticalCenter: (icon.visible && !bodyLabel.visible) ? icon.verticalCenter : undefined

                    Label {
                        id: summaryLabel

                        objectName: "summaryLabel"
                        anchors {
                            left: parent.left
                            right: parent.right
                        }
                        fontSize: "medium"
                        font.bold: true
                        color: Theme.palette.selected.backgroundText
                        elide: Text.ElideRight
                    }

                    Label {
                        id: bodyLabel

                        objectName: "bodyLabel"
                        anchors {
                            left: parent.left
                            right: parent.right
                        }
                        visible: body != ""
                        fontSize: "small"
                        color: Theme.palette.selected.backgroundText
                        opacity: 0.6
                        wrapMode: Text.WordWrap
                        maximumLineCount: 10
                        elide: Text.ElideRight
                    }
                }
            }

            Column {
                objectName: "dialogListView"
                spacing: units.gu(2)

                visible: count > 0

                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: fullscreen ? parent.top : undefined
                anchors.bottom: fullscreen ? parent.bottom : undefined

                Repeater {
                    model: unityMenuModel

                    NotificationMenuItemFactory {
                        id: menuItemFactory

                        anchors.left: parent.left; anchors.right: parent.right

                        menuModel: unityMenuModel
                        menuData: model
                        menuIndex: index
                        maxHeight: notification.maxHeight

                        onLoaded: {
                            notification.fullscreen = Qt.binding(function() { return fullscreen; });
                        }
                    }
                }
            }

            Row {
                id: buttonRow

                objectName: "buttonRow"
                anchors {
                    left: parent.left
                    right: parent.right
                }
                visible: notification.type == Notification.SnapDecision && actionRepeater.count > 0
                spacing: units.gu(1)
                layoutDirection: Qt.RightToLeft

                Repeater {
                    id: actionRepeater

                    model: notification.actions
                    delegate: Loader {
                        id: loader

                        property string actionId: id
                        property string actionLabel: label

                        Component {
                            id: actionButton

                            Button {
                                objectName: "button" + index
                                width: buttonRow.width / 2 - spacing
                                text: loader.actionLabel
                                gradient: notification.hints["x-canonical-private-button-tint"] == "true" && index == 0 ? greenGradient : darkgreyGradient
                                onClicked: notification.notification.invokeAction(loader.actionId)
                            }
                        }
                        sourceComponent: (index == 0 || index == 1) ? actionButton : undefined
                    }
                }
            }

            ComboButton {
                width: parent.width
                text: "Decline"
                visible: notification.type == Notification.SnapDecision && actionRepeater.count > 2
                gradient: darkgreyGradient
                onClicked: print ("Clicked on " + text)
                expanded: false
                expandedHeight: (actionRepeater.count) * units.gu(4)
                comboList: ListView {
                    id: myView

                    width: parent.width
                    interactive: false

                    model: notification.actions
                    delegate: Column {
                        id: myDelegate

                        width: parent.width

                        ListItem.ThinDivider {
                            visible: index != 0
                        }

                        MouseArea {
                            id: localInputArea

                            x: localIcon.x
                            y: localIcon.y
                            width: parent.width
                            height: localIcon.height + units.gu(1)

                            onClicked: {
                                notification.notification.invokeAction(id)
                            }

                            Icon {
                                id: localIcon

                                anchors.left: parent.left
                                anchors.leftMargin: units.gu(.5)
                                anchors.top: parent.top
                                anchors.topMargin: units.gu(.5)
                                width: units.gu(2)
                                height: units.gu(2)
                                name: "messages"
                                color: "white"
                            }

                            Label {
                                id: localLabel

                                anchors.left: localIcon.right
                                anchors.leftMargin: units.gu(.5)
                                height: localIcon.height
                                verticalAlignment: Text.AlignVCenter
                                fontSize: "small"
                                color: "white"
                                text: label
                            }
                        }
                    }
                }
            }
        }
    }
}
