#!/usr/bin/perl

use strict;
use warnings;
use CGI;
use File::Basename;

# Publish firmware upload progress to /misc/fwDownloadProgress as the request body
# arrives (requires server.stream-request-body in lighttpd.conf).
my $content_length = $ENV{'CONTENT_LENGTH'} || 0;
my $last_progress = -1;
my $progress_reported = 0;
my $progress_finished = 0;

sub set_fw_download_progress {
    my ($progress) = @_;
    $progress = int($progress);
    # stdout is the HTTP response, so keep ipcTool output out of it
    system("ipcTool --port=1236 --url=/misc --method=set --params='{\"fwDownloadProgress\":$progress}' >/dev/null 2>&1");
}

sub upload_hook {
    my ($client_filename, $buffer, $bytes_read) = @_;
    # only firmware archives, matching what sftp-monitor.sh handles
    return unless $content_length > 0 && defined $client_filename && $client_filename =~ /\.tar\.xz\.enc$/i;
    my $progress = int($bytes_read * 100 / $content_length);
    # the request body includes multipart overhead; 100 is published once the file is saved
    $progress = 99 if $progress > 99;
    return if $progress == $last_progress;
    $last_progress = $progress;
    $progress_reported = 1;
    set_fw_download_progress($progress);
}

# clear progress if the upload failed or turned out not to be a firmware update
END {
    set_fw_download_progress(0) if $progress_reported && !$progress_finished;
}

my $q = CGI->new(\&upload_hook, undef, 1);

sub h {
    my ($s) = @_;
    $s = '' unless defined $s;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g;
    $s =~ s/'/&#39;/g;
    return $s;
}

my $method = $ENV{'REQUEST_METHOD'} // '';

print $q->header('text/html');
print "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><title>Upload Result</title></head><body>";
print "<h1>Perl CGI Upload Test</h1>";

if ($method ne 'POST') {
    print "<p>Expected POST request. Got: <b>" . h($method) . "</b></p>";
    print "<p><a href=\"/\">Back</a></p></body></html>";
    exit 0;
}

my $filename = $q->param('file') // '';
my $category = $q->param('category') // 'misc-files';
my $metadata_json = $q->param('metadata_json');
my $upload_fh = $q->upload('file');

$metadata_json = '' unless defined $metadata_json;
$metadata_json =~ s/\r\n/\n/g;
my $metadata_present = ($metadata_json =~ /\S/) ? 1 : 0;
my $metadata_valid = 0;
my $metadata_error = '';

if ($metadata_present) {
    my $decode_ok = eval {
        require JSON::PP;
        JSON::PP->new->decode($metadata_json);
        1;
    };
    if ($decode_ok) {
        $metadata_valid = 1;
    } else {
        $metadata_error = $@ || 'Invalid JSON';
        $metadata_error =~ s/\s+$//;
    }
}

if (!$filename || !$upload_fh) {
    print "<h2>Error</h2>";
    print "<p>No file was uploaded.</p>";
    print "<p><a href=\"/\">Back</a></p></body></html>";
    exit 0;
}

$filename = basename($filename);

my %category_dir = (
    'firmware-update' => '/var/tmp/sftp',
    'audio-files'     => '/mnt/data/audio-files',
    'image-files'     => '/mnt/data/image-files',
    'misc-files'      => '/mnt/data/misc-files',
);

if (!exists $category_dir{$category}) {
    $category = 'firmware-update'; # default here for backward compatibility (802.1x certs are handled by sftp-monitor service)
}

my $destination_dir = $category_dir{$category};
my $server_path = "$destination_dir/$filename";

print STDERR "upload.cgi - filename=" . $filename . ", category=" . $category . ", destination_dir=" . $destination_dir . "\n";

my $output_fh;
if (!open($output_fh, '>', $server_path)) {
    print "<h2>Error</h2>";
    print "<p>Could not open destination file for writing.</p>";
    print "<p>Path: <code>" . h($server_path) . "</code></p>";
    print "<p><a href=\"/\">Back</a></p></body></html>";
    exit 1;
}

binmode($upload_fh);
binmode($output_fh);

my $written = 0;
while (read($upload_fh, my $buf, 4096)) {
    print {$output_fh} $buf;
    $written += length($buf);
}

close($output_fh);
close($upload_fh);

if ($progress_reported && $category eq 'firmware-update') {
    set_fw_download_progress(100);
    $progress_finished = 1;
}

my $metadata_path = "$server_path.metadata.json";
if ($metadata_present && $metadata_valid) {
    if (open(my $meta_fh, '>', $metadata_path)) {
        print {$meta_fh} $metadata_json;
        print {$meta_fh} "\n" unless $metadata_json =~ /\n\z/;
        close($meta_fh);
    } else {
        $metadata_error = "Could not write metadata file";
    }
}

my $temp_filepath = $q->tmpFileName($filename);
if (defined $temp_filepath && -e $temp_filepath) {
    unlink($temp_filepath);
}

print "<p>Bytes written: <b>$written</b></p>";
print "<p>File: <code>" . h($filename) . "</code></p>";
print "<p>Category: <code>" . h($category) . "</code></p>";
print "<p>Saved to: <code>" . h($server_path) . "</code></p>";
if ($metadata_present) {
    if ($metadata_valid && !$metadata_error) {
        print "<p>Metadata: <b>accepted</b></p>";
        print "<p>Metadata file: <code>" . h($metadata_path) . "</code></p>";
    } else {
        print "<p>Metadata: <b>rejected</b></p>";
        print "<p>Reason: <code>" . h($metadata_error) . "</code></p>";
    }
} else {
    print "<p>Metadata: <b>not provided</b></p>";
}
print "<p><a href=\"/upload-test.html\">Back</a></p>";
print "</body></html>";
