#include <stdio.h>
#include "cgic.h"
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <libgen.h> /* for basename() */

void HandleSubmit();
void FileUpload();

int cgiMain() {
	cgiHeaderContentType("text/html");
	fprintf(cgiOut, "<HTML><HEAD>\n");
	fprintf(cgiOut, "<TITLE>http-multipart-form-data-upload</TITLE></HEAD>\n");
	fprintf(cgiOut, "<BODY><H1>http-multipart-form-data-upload</H1>\n");
	if ((cgiFormSubmitClicked("http-multipart-form-data-upload") == cgiFormSuccess)) {
		FileUpload();
	}
	else {
	  fprintf(cgiOut, "error: http-multipart-form-data-upload form not submitted\n");
	}
	fprintf(cgiOut, "</BODY></HTML>\n");
	return 0;
}

/* http file upload handler */
void FileUpload()
{
	#define BUF_LEN 1024
	#define UPLOAD_DIR "/var/tmp/sftp/" // upload here
	static char name[BUF_LEN];
	static char path[BUF_LEN];
	static char contentType[BUF_LEN];
	int size;
	char *safeName;
	char *tmpPath;
	if (cgiFormFileName("file", name, sizeof(name)) != cgiFormSuccess) {
		fprintf(stderr, "<p>error: No file was uploaded.\n");
		return;
	} 
	if (cgiFormFileSize("file", &size) != cgiFormSuccess) {
		fprintf(stderr, "<p>error: Can't get file size.\n");
		return;
	} 
	if (cgiFormFileContentType("file", contentType, sizeof(contentType)) != cgiFormSuccess) {
		fprintf(stderr, "<p>error: Can't get file contentType.\n");
		return;
	} 
	if (cgiFormFileGetPath("file", &tmpPath) != cgiFormSuccess) {
		fprintf(stderr, "<p>error: Can't get file tmp path.\n");
		return;
	} 
	safeName = basename(name);
	strncpy(path, UPLOAD_DIR, sizeof(path));
	strncat(path, safeName, sizeof(path)-strlen(path)-1);
	fprintf(cgiOut, "<p>Uploaded file: path='%s', size=%d, contentType='%s', tmp path='%s'\n", path, size, contentType, tmpPath);
	/* move the tmp file into UPLOAD_DIR with it's supplied name so the sftp-monitor service can process it */
	char command[256];
	sprintf(command, "mv %s %s\n", tmpPath, path);
	if (system(command)) {
		fprintf(cgiOut, "<p>error: mv failure, errno=%d\n", errno);
	}
	else {
		fprintf(cgiOut, "<p>Success!\n");
	}

}
