#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <Speech/Speech.h>

#include "speech.h"

#include <atomic>
#include <mutex>

// =====================================
// SPEAK (macOS `say`)
// =====================================

static NSTask* g_speaking_task = nil;

static std::mutex g_speak_mutex;

void speech::stop_speaking()
{
    std::lock_guard<std::mutex> lock(g_speak_mutex);

    NSTask* task = g_speaking_task;

    g_speaking_task = nil;

    if (task) {

        if ([task isRunning]) {
            [task terminate];
            [task waitUntilExit];
        }

        task = nil;
    }
}

void speech::speak(const std::string& text)
{
    speech::stop_speaking();

    std::printf("JARVIS: %s\n", text.c_str());

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{

        @try {

            NSTask* task = [[NSTask alloc] init];

            task.launchPath = @"/usr/bin/say";
            task.arguments = @[[NSString stringWithUTF8String:text.c_str()]];

            {
                std::lock_guard<std::mutex> lock(g_speak_mutex);
                g_speaking_task = task;
            }

            [task launch];

            [task waitUntilExit];

            {
                std::lock_guard<std::mutex> lock(g_speak_mutex);
                if (g_speaking_task == task) {
                    g_speaking_task = nil;
                }
            }

        } @catch (NSException* exception) {
            // Игнорируем ошибки озвучки
        }
    });
}

// =====================================
// LISTEN (Apple Speech Framework)
// =====================================

static std::atomic<bool> g_listening{false};

static std::function<void(const std::string&)> g_on_text;

static SFSpeechRecognizer* g_recognizer = nil;

static SFSpeechAudioBufferRecognitionRequest* g_request = nil;

static AVAudioEngine* g_engine = nil;

static NSTimer* g_silence_timer = nil;

static NSMutableString* g_heard = nil;

static double g_last_change = 0.0;

static double now_seconds()
{
    return [[NSDate date] timeIntervalSinceReferenceDate];
}

static void deliver_result()
{
    std::string text = g_heard ? std::string([g_heard UTF8String]) : std::string();

    auto callback = g_on_text;

    g_heard = nil;

    g_on_text = nullptr;

    if (callback) {
        callback(text);
    }
}

static void finish_listening()
{
    if (!g_listening.exchange(false)) {
        return;
    }

    if (g_silence_timer) {
        [g_silence_timer invalidate];
        g_silence_timer = nil;
    }

    if (g_engine) {
        [g_engine.inputNode removeTapOnBus:0];
        [g_engine stop];
        g_engine = nil;
    }

    if (g_request) {
        [g_request endAudio];
        g_request = nil;
    }

    g_recognizer = nil;

    // Колбэк на главном потоке
    dispatch_async(dispatch_get_main_queue(), ^{
        deliver_result();
    });
}

static void install_recognizer();

void speech::start_listening(std::function<void(const std::string&)> on_text)
{
    if (g_listening.load()) {
        return;
    }

    g_on_text = std::move(on_text);

    dispatch_async(dispatch_get_main_queue(), ^{

        [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {

            dispatch_async(dispatch_get_main_queue(), ^{

                if (status != SFSpeechRecognizerAuthorizationStatusAuthorized) {
                    std::printf("Speech authorization failed: %ld\n", (long)status);
                    auto cb = g_on_text;
                    g_on_text = nullptr;
                    if (cb) {
                        cb("");
                    }
                    return;
                }

                install_recognizer();
            });
        }];
    });
}

static void install_recognizer()
{
    g_listening = true;

    g_heard = [NSMutableString new];

    g_last_change = now_seconds();

    g_recognizer = [[SFSpeechRecognizer alloc]
        initWithLocale:[NSLocale localeWithLocaleIdentifier:@"ru-RU"]];

    if (!g_recognizer || !g_recognizer.isAvailable) {
        finish_listening();
        return;
    }

    g_request = [[SFSpeechAudioBufferRecognitionRequest alloc] init];

    g_request.shouldReportPartialResults = YES;

    g_engine = [[AVAudioEngine alloc] init];

    AVAudioInputNode* input = g_engine.inputNode;

    AVAudioFormat* format = [input outputFormatForBus:0];

    [input installTapOnBus:0
                bufferSize:4096
                    format:format
                     block:^(AVAudioPCMBuffer* buffer, AVAudioTime* when) {

                         [g_request appendAudioPCMBuffer:buffer];
                     }];

    [g_engine prepare];

    [g_engine startAndReturnError:nil];

    [g_recognizer recognitionTaskWithRequest:g_request
        resultHandler:^(SFSpeechRecognitionResult* result, NSError* error) {

            dispatch_async(dispatch_get_main_queue(), ^{

                if (result) {

                    NSString* text = result.bestTranscription.formattedString;

                    if (text) {
                        [g_heard setString:text];
                        g_last_change = now_seconds();
                    }

                    if (result.isFinal) {
                        finish_listening();
                    }
                }

                if (error) {
                    std::printf("Speech error: %s\n",
                                error.localizedDescription.UTF8String ?: "unknown");
                    finish_listening();
                }
            });
        }];

    g_silence_timer = [NSTimer scheduledTimerWithTimeInterval:0.5
        repeats:YES
        block:^(NSTimer* timer) {

            if (!g_heard || g_heard.length == 0) {
                return;
            }

            if (now_seconds() - g_last_change > 2.0) {
                finish_listening();
            }
        }];
}

void speech::stop_listening()
{
    dispatch_async(dispatch_get_main_queue(), ^{
        finish_listening();
    });
}

bool speech::is_listening()
{
    return g_listening.load();
}
