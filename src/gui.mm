#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

#include "ai.h"
#include "commands.h"
#include "executor.h"
#include "memory.h"
#include "speech.h"

#include <string>
#include <thread>

// =====================================
// ATTRIBUTED STRING HELPERS
// =====================================

static NSAttributedString* attributed(NSString* string, NSFont* font, NSColor* color)
{
    NSDictionary* attributes = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: color,
    };

    return [[NSAttributedString alloc] initWithString:string attributes:attributes];
}

static NSAttributedString* bold_message(NSString* sender, NSColor* color)
{
    return attributed(sender, [NSFont boldSystemFontOfSize:15], color);
}

static NSAttributedString* body_message(NSString* text)
{
    return attributed(text, [NSFont systemFontOfSize:15], [NSColor labelColor]);
}

static NSAttributedString* newline()
{
    return attributed(@"\n", [NSFont systemFontOfSize:15], [NSColor labelColor]);
}

// =====================================
// CONTROLLER
// =====================================

@interface JarvisController : NSObject <NSWindowDelegate, NSApplicationDelegate>

@property(strong) NSWindow* window;

@property(strong) NSTextView* chat;

@property(strong) NSTextField* entry;

@property(strong) NSTextField* statusLabel;

@property(strong) NSButton* voiceButton;

@property(strong) NSString* attachedImage;

@property(strong) NSString* attachedScreen;

- (void)sendText:(id)sender;

- (void)voiceInput:(id)sender;

- (void)uploadImage:(id)sender;

- (void)analyzeScreen:(id)sender;

- (void)clearChatMemory:(id)sender;

- (void)stopSpeaking:(id)sender;

@end

@implementation JarvisController

// =====================================
// STATUS BAR
// =====================================

- (void)updateStatus
{
    NSMutableArray* parts = [NSMutableArray array];

    if (self.attachedImage) {
        [parts addObject:[NSString stringWithFormat:@"📎 %@",
            [self.attachedImage lastPathComponent]]];
    }

    if (self.attachedScreen) {
        [parts addObject:[NSString stringWithFormat:@"👁 %@",
            [self.attachedScreen lastPathComponent]]];
    }

    [parts addObject:[NSString stringWithFormat:@"🤖 %s", ai::active_model_label().c_str()]];

    [parts addObject:[NSString stringWithFormat:@"💬 %d сообщений", ai::message_count()]];

    self.statusLabel.stringValue = [parts componentsJoinedByString:@" | "];
}

// =====================================
// CHAT LOG
// =====================================

- (void)scrollBottom
{
    NSUInteger length = self.chat.string.length;

    NSRange range = NSMakeRange(length > 0 ? length - 1 : 0, 1);

    [self.chat scrollRangeToVisible:range];
}

- (void)appendAttributedString:(NSAttributedString*)string
{
    [[self.chat textStorage] appendAttributedString:string];

    [self scrollBottom];
}

- (void)appendMessage:(NSString*)sender
                 text:(NSString*)text
                color:(NSColor*)color
{
    NSMutableAttributedString* message = [NSMutableAttributedString new];

    [message appendAttributedString:bold_message(
        [NSString stringWithFormat:@"%@: ", sender], color)];

    [message appendAttributedString:body_message(text)];

    [message appendAttributedString:newline()];

    [message appendAttributedString:newline()];

    [self appendAttributedString:message];
}

- (void)appendSystem:(NSString*)text
{
    [self appendMessage:@"Система" text:text color:[NSColor systemGrayColor]];
}

// =====================================
// IMAGES IN CHAT
// =====================================

- (void)appendUserImage:(NSString*)imagePath
{
    NSImage* image = [[NSImage alloc] initWithContentsOfFile:imagePath];

    if (!image) {
        [self appendMessage:@"Ошибка"
                       text:@"Не удалось открыть изображение"
                      color:[NSColor systemRedColor]];
        return;
    }

    NSSize size = [image size];

    double scale = MIN(1.0, MIN(400.0 / MAX(size.width, 1.0), 400.0 / MAX(size.height, 1.0)));

    [image setSize:NSMakeSize(size.width * scale, size.height * scale)];

    NSTextAttachment* attachment = [[NSTextAttachment alloc] init];

    attachment.attachmentCell = [[NSTextAttachmentCell alloc] initImageCell:image];

    NSMutableAttributedString* message = [NSMutableAttributedString new];

    [message appendAttributedString:bold_message(@"Ты:", [NSColor systemGreenColor])];

    [message appendAttributedString:newline()];

    [message appendAttributedString:[NSAttributedString
        attributedStringWithAttachment:attachment]];

    [message appendAttributedString:newline()];

    [message appendAttributedString:newline()];

    [self appendAttributedString:message];
}

// =====================================
// AI THREAD
// =====================================

- (void)runAi:(std::string)prompt image:(std::string)imagePath
{
    try {

        std::string response = ai::ask_ai(prompt, imagePath);

        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleResponse:response];
        });

    } catch (const std::exception& error) {

        std::string message = error.what();

        dispatch_async(dispatch_get_main_queue(), ^{
            [self appendMessage:@"Ошибка"
                           text:[NSString stringWithUTF8String:message.c_str()]
                          color:[NSColor systemRedColor]];
        });
    }
}

- (void)handleResponse:(std::string)response
{
    // =========================
    // ACTION
    // =========================

    if (response.rfind("ACTION:", 0) == 0) {

        std::string result = executor::execute_ai_action(response);

        if (!result.empty()) {

            NSString* action = [NSString stringWithUTF8String:result.c_str()];

            [self appendMessage:@"JARVIS"
                           text:action
                          color:[NSColor systemBlueColor]];

            speech::speak(result);

            return;
        }
    }

    // =========================
    // CLEAN OUTPUT
    // =========================

    std::string cleaned = ai::clean_ai_output(response);

    NSString* text = [NSString stringWithUTF8String:cleaned.c_str()];

    [self appendMessage:@"JARVIS" text:text color:[NSColor systemBlueColor]];

    [self updateStatus];

    speech::speak(cleaned);
}

// =====================================
// TEXT SENDER
// =====================================

- (void)sendText:(id)sender
{
    NSString* text = self.entry.stringValue;

    self.entry.stringValue = @"";

    BOOL hasText = [[text stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]] length] > 0;

    if (!hasText && !self.attachedImage) {
        return;
    }

    NSString* imagePath = self.attachedImage ?: self.attachedScreen;

    self.attachedImage = nil;

    self.attachedScreen = nil;

    [self updateStatus];

    // Картинка пользователя в чат
    if (imagePath) {
        [self appendUserImage:imagePath];
    }

    // Текст пользователя в чат
    if (hasText) {
        [self appendMessage:@"Ты" text:text color:[NSColor systemGreenColor]];
    }

    std::string prompt = hasText
        ? std::string(text.UTF8String)
        : "Опиши изображение.";

    std::string image = imagePath ? std::string(imagePath.UTF8String) : std::string();

    std::thread([self, prompt, image] {
        [self runAi:prompt image:image];
    }).detach();
}

// =====================================
// VOICE
// =====================================

- (void)voiceInput:(id)sender
{
    if (speech::is_listening()) {
        speech::stop_listening();
        return;
    }

    speech::start_listening([self](const std::string& heard) {

        dispatch_async(dispatch_get_main_queue(), ^{

            NSString* text = [NSString stringWithUTF8String:heard.c_str()];

            if (text.length == 0) {
                return;
            }

            [self processMessage:text];
        });
    });

    [self appendSystem:@"🎤 Слушаю..."];
}

- (void)processMessage:(NSString*)text
{
    [self appendMessage:@"Ты" text:text color:[NSColor systemGreenColor]];

    // Прямые команды (ютуб, гугл, сафари, музыка)
    std::string command_result = commands::execute_command(std::string(text.UTF8String));

    if (!command_result.empty()) {

        NSString* reply = [NSString stringWithUTF8String:command_result.c_str()];

        [self appendMessage:@"JARVIS" text:reply color:[NSColor systemBlueColor]];

        speech::speak(command_result);

        return;
    }

    std::string prompt = std::string(text.UTF8String);

    std::thread([self, prompt] {
        [self runAi:prompt image:""];
    }).detach();
}

// =====================================
// IMAGE UPLOAD
// =====================================

- (void)uploadImage:(id)sender
{
    NSOpenPanel* panel = [NSOpenPanel openPanel];

    panel.allowedFileTypes = @[@"png", @"jpg", @"jpeg"];

    panel.canChooseFiles = YES;

    panel.canChooseDirectories = NO;

    if ([panel runModal] != NSModalResponseOK || panel.URLs.count == 0) {
        return;
    }

    NSString* path = panel.URLs.firstObject.path;

    self.attachedImage = path;

    [self updateStatus];

    [self appendSystem:[NSString stringWithFormat:@"📎 Прикреплено изображение: %@",
        [path lastPathComponent]]];
}

// =====================================
// SCREEN ANALYSIS
// =====================================

- (void)analyzeScreen:(id)sender
{
    NSFileManager* fileManager = [NSFileManager defaultManager];

    NSString* directory = [fileManager currentDirectoryPath];

    // Запуск из Finder: рабочая папка "/" — используем домашнюю
    if (directory.length == 0 || [directory isEqualToString:@"/"]) {
        directory = NSHomeDirectory();
    }

    NSString* screensDir = [directory stringByAppendingPathComponent:@"screens"];

    NSError* error = nil;

    [fileManager createDirectoryAtPath:screensDir
          withIntermediateDirectories:YES
                           attributes:nil
                                error:&error];

    // NSFileManager не проверяет запись напрямую: пробуем создать временный файл
    NSString* probe = [screensDir stringByAppendingPathComponent:@".write-probe"];

    BOOL writable = [@"ok" writeToFile:probe
                            atomically:YES
                              encoding:NSUTF8StringEncoding
                                 error:nil];

    if (writable) {
        [fileManager removeItemAtPath:probe error:nil];
    } else {
        screensDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"jarvis-screens"];
        [fileManager createDirectoryAtPath:screensDir
              withIntermediateDirectories:YES
                               attributes:nil
                                    error:nil];
    }

    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];

    formatter.dateFormat = @"yyyy-MM-dd_HH-mm-ss";

    NSString* stamp = [formatter stringFromDate:[NSDate date]];

    NSString* screenshotPath =
        [screensDir stringByAppendingPathComponent:
            [NSString stringWithFormat:@"screen_%@.png", stamp]];

    [NSTask launchedTaskWithLaunchPath:@"/usr/sbin/screencapture"
                            arguments:@[@"-x", screenshotPath]];

    self.attachedScreen = screenshotPath;

    [self updateStatus];

    [self appendSystem:@"👁 Скриншот прикреплён"];
}

// =====================================
// MEMORY
// =====================================

- (void)clearChatMemory:(id)sender
{
    self.attachedImage = nil;

    self.attachedScreen = nil;

    ai::clear_memory();

    [self updateStatus];

    [self appendSystem:@"🧠 Контекст очищен."];
}

- (void)stopSpeaking:(id)sender
{
    speech::stop_speaking();
}

// =====================================
// WINDOW DELEGATE
// =====================================

- (BOOL)windowShouldClose:(NSWindow*)window
{
    [NSApp terminate:self];

    return YES;
}

// =====================================
// BUILD UI
// =====================================

- (void)buildWindow
{
    NSRect frame = NSMakeRect(0, 0, 1000, 700);

    self.window = [[NSWindow alloc]
        initWithContentRect:frame
                  styleMask:NSWindowStyleMaskTitled
                          | NSWindowStyleMaskClosable
                          | NSWindowStyleMaskMiniaturizable
                          | NSWindowStyleMaskResizable
                    backing:NSBackingStoreBuffered
                      defer:NO];

    self.window.minSize = NSMakeSize(800, 600);

    self.window.title = @"JARVIS";

    self.window.delegate = self;

    self.window.backgroundColor = [NSColor colorWithCalibratedWhite:0.11 alpha:1.0];

    [self.window center];

    NSView* content = self.window.contentView;

    // =========================
    // CHAT AREA
    // =========================

    NSScrollView* scroller = [[NSScrollView alloc] initWithFrame:NSZeroRect];

    scroller.translatesAutoresizingMaskIntoConstraints = NO;

    scroller.borderType = NSNoBorder;

    scroller.hasVerticalScroller = YES;

    scroller.drawsBackground = NO;

    self.chat = [[NSTextView alloc]
        initWithFrame:NSMakeRect(0, 0, 984, 616)];

    self.chat.minSize = NSZeroSize;

    self.chat.maxSize = NSMakeSize(FLT_MAX, FLT_MAX);

    self.chat.autoresizingMask = NSViewWidthSizable;

    self.chat.editable = NO;

    self.chat.richText = YES;

    self.chat.drawsBackground = YES;

    self.chat.backgroundColor = [NSColor colorWithCalibratedWhite:0.12 alpha:1.0];

    self.chat.textContainerInset = NSSize{20, 16};

    self.chat.verticallyResizable = YES;

    self.chat.textContainer.widthTracksTextView = YES;

    scroller.documentView = self.chat;

    [content addSubview:scroller];

    // Укладываем раскладку и задаём document view точный размер
    [content layoutSubtreeIfNeeded];

    NSSize contentSize = scroller.contentSize;

    self.chat.frame = NSMakeRect(0, 0, contentSize.width, contentSize.height);

    self.chat.minSize = NSMakeSize(0, contentSize.height);

    // =========================
    // STATUS LABEL
    // =========================

    self.statusLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];

    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;

    self.statusLabel.editable = NO;

    self.statusLabel.bordered = NO;

    self.statusLabel.drawsBackground = NO;

    self.statusLabel.font = [NSFont systemFontOfSize:11];

    self.statusLabel.textColor = [NSColor secondaryLabelColor];

    self.statusLabel.stringValue = @"Готов";

    [content addSubview:self.statusLabel];

    // =========================
    // BOTTOM BAR
    // =========================

    self.entry = [[NSTextField alloc] initWithFrame:NSZeroRect];

    self.entry.translatesAutoresizingMaskIntoConstraints = NO;

    self.entry.font = [NSFont systemFontOfSize:16];

    self.entry.placeholderString = @"Скажи мне что-нибудь...";

    self.entry.target = self;

    self.entry.action = @selector(sendText:);

    [content addSubview:self.entry];

    auto make_button = ^(NSString* title, CGFloat width, SEL action) {

        NSButton* button = [[NSButton alloc] initWithFrame:NSZeroRect];

        button.translatesAutoresizingMaskIntoConstraints = NO;

        button.title = title;

        button.bezelStyle = NSBezelStyleRounded;

        button.target = self;

        button.action = action;

        [content addSubview:button];

        [content addConstraint:
            [NSLayoutConstraint constraintWithItem:button
                                         attribute:NSLayoutAttributeWidth
                                         relatedBy:NSLayoutRelationEqual
                                            toItem:nil
                                         attribute:NSLayoutAttributeNotAnAttribute
                                        multiplier:1.0
                                          constant:width]];

        return button;
    };

    NSButton* sendButton = make_button(@"Отправить", 115, @selector(sendText:));

    self.voiceButton = make_button(@"🎤", 52, @selector(voiceInput:));

    NSButton* attachButton = make_button(@"📎", 52, @selector(uploadImage:));

    NSButton* screenButton = make_button(@"👁", 52, @selector(analyzeScreen:));

    NSButton* stopButton = make_button(@"⛔", 52, @selector(stopSpeaking:));

    NSButton* memoryButton = make_button(@"🧠", 52, @selector(clearChatMemory:));

    // =========================
    // CONSTRAINTS
    // =========================

    NSArray<NSLayoutConstraint*>* constraints = @[
        // chat: верх/бока к окну, низ — над статус-строкой
        [NSLayoutConstraint constraintWithItem:scroller
                                     attribute:NSLayoutAttributeTop
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:content
                                     attribute:NSLayoutAttributeTop
                                    multiplier:1.0
                                      constant:0],
        [NSLayoutConstraint constraintWithItem:scroller
                                     attribute:NSLayoutAttributeLeading
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:content
                                     attribute:NSLayoutAttributeLeading
                                    multiplier:1.0
                                      constant:0],
        [NSLayoutConstraint constraintWithItem:scroller
                                     attribute:NSLayoutAttributeTrailing
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:content
                                     attribute:NSLayoutAttributeTrailing
                                    multiplier:1.0
                                      constant:0],
        [NSLayoutConstraint constraintWithItem:scroller
                                     attribute:NSLayoutAttributeBottom
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self.statusLabel
                                     attribute:NSLayoutAttributeTop
                                    multiplier:1.0
                                      constant:-6],

        // статус: над полем ввода
        [NSLayoutConstraint constraintWithItem:self.statusLabel
                                     attribute:NSLayoutAttributeLeading
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:content
                                     attribute:NSLayoutAttributeLeading
                                    multiplier:1.0
                                      constant:16],
        [NSLayoutConstraint constraintWithItem:self.statusLabel
                                     attribute:NSLayoutAttributeTrailing
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:content
                                     attribute:NSLayoutAttributeTrailing
                                    multiplier:1.0
                                      constant:-16],
        [NSLayoutConstraint constraintWithItem:self.statusLabel
                                     attribute:NSLayoutAttributeBottom
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self.entry
                                     attribute:NSLayoutAttributeTop
                                    multiplier:1.0
                                      constant:-4],
        [NSLayoutConstraint constraintWithItem:self.statusLabel
                                     attribute:NSLayoutAttributeHeight
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:nil
                                     attribute:NSLayoutAttributeNotAnAttribute
                                    multiplier:1.0
                                      constant:15],

        // ввод: снизу слева, тянется до кнопки "Отправить"
        [NSLayoutConstraint constraintWithItem:self.entry
                                     attribute:NSLayoutAttributeLeading
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:content
                                     attribute:NSLayoutAttributeLeading
                                    multiplier:1.0
                                      constant:10],
        [NSLayoutConstraint constraintWithItem:self.entry
                                     attribute:NSLayoutAttributeBottom
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:content
                                     attribute:NSLayoutAttributeBottom
                                    multiplier:1.0
                                      constant:-10],
        [NSLayoutConstraint constraintWithItem:self.entry
                                     attribute:NSLayoutAttributeTop
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self.statusLabel
                                     attribute:NSLayoutAttributeBottom
                                    multiplier:1.0
                                      constant:4],
        [NSLayoutConstraint constraintWithItem:sendButton
                                     attribute:NSLayoutAttributeLeading
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self.entry
                                     attribute:NSLayoutAttributeTrailing
                                    multiplier:1.0
                                      constant:8],

        // кнопки в ряд, по центру поля ввода
        [NSLayoutConstraint constraintWithItem:sendButton
                                     attribute:NSLayoutAttributeCenterY
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self.entry
                                     attribute:NSLayoutAttributeCenterY
                                    multiplier:1.0
                                      constant:0],
        [NSLayoutConstraint constraintWithItem:self.voiceButton
                                     attribute:NSLayoutAttributeLeading
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:sendButton
                                     attribute:NSLayoutAttributeTrailing
                                    multiplier:1.0
                                      constant:8],
        [NSLayoutConstraint constraintWithItem:self.voiceButton
                                     attribute:NSLayoutAttributeCenterY
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self.entry
                                     attribute:NSLayoutAttributeCenterY
                                    multiplier:1.0
                                      constant:0],
        [NSLayoutConstraint constraintWithItem:attachButton
                                     attribute:NSLayoutAttributeLeading
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self.voiceButton
                                     attribute:NSLayoutAttributeTrailing
                                    multiplier:1.0
                                      constant:8],
        [NSLayoutConstraint constraintWithItem:attachButton
                                     attribute:NSLayoutAttributeCenterY
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self.entry
                                     attribute:NSLayoutAttributeCenterY
                                    multiplier:1.0
                                      constant:0],
        [NSLayoutConstraint constraintWithItem:screenButton
                                     attribute:NSLayoutAttributeLeading
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:attachButton
                                     attribute:NSLayoutAttributeTrailing
                                    multiplier:1.0
                                      constant:8],
        [NSLayoutConstraint constraintWithItem:screenButton
                                     attribute:NSLayoutAttributeCenterY
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self.entry
                                     attribute:NSLayoutAttributeCenterY
                                    multiplier:1.0
                                      constant:0],
        [NSLayoutConstraint constraintWithItem:stopButton
                                     attribute:NSLayoutAttributeLeading
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:screenButton
                                     attribute:NSLayoutAttributeTrailing
                                    multiplier:1.0
                                      constant:8],
        [NSLayoutConstraint constraintWithItem:stopButton
                                     attribute:NSLayoutAttributeCenterY
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self.entry
                                     attribute:NSLayoutAttributeCenterY
                                    multiplier:1.0
                                      constant:0],
        [NSLayoutConstraint constraintWithItem:memoryButton
                                     attribute:NSLayoutAttributeLeading
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:stopButton
                                     attribute:NSLayoutAttributeTrailing
                                    multiplier:1.0
                                      constant:8],
        [NSLayoutConstraint constraintWithItem:memoryButton
                                     attribute:NSLayoutAttributeTrailing
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:content
                                     attribute:NSLayoutAttributeTrailing
                                    multiplier:1.0
                                      constant:-12],
        [NSLayoutConstraint constraintWithItem:memoryButton
                                     attribute:NSLayoutAttributeCenterY
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self.entry
                                     attribute:NSLayoutAttributeCenterY
                                    multiplier:1.0
                                      constant:0],
    ];

    [content addConstraints:constraints];

    // =========================
    // SHOW
    // =========================

    [self updateStatus];

    [self appendMessage:@"JARVIS"
                   text:@"К вашим услугам, сэр. Спросите что-нибудь, "
                        @"нажмите 🎤 для голосового ввода или 👁, "
                        @"чтобы я посмотрел на экран."
                 color:[NSColor systemBlueColor]];

    [self.window makeKeyAndOrderFront:nil];
}

@end

namespace gui {

void run()
{
    [NSApplication sharedApplication];

    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

    [NSApp setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];

    static JarvisController* controller = [JarvisController new];

    [NSApp setDelegate:controller];

    [controller buildWindow];

    [NSApp activateIgnoringOtherApps:YES];

    [NSApp run];
}

} // namespace gui
