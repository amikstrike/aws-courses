provider "aws" {
  profile = "default"
  region  = "us-west-2"
}

resource "aws_sns_topic_subscription" "subscription" {
  endpoint = aws_sqs_queue.aws_oivchenko_queue.arn
  protocol = "sqs"
  topic_arn = aws_sns_topic.aws_oivchenko_topic.arn
}


resource "aws_sqs_queue_policy" "queue_policy" {
  queue_url = aws_sqs_queue.aws_oivchenko_queue.id
  policy = <<POLICY
    {
      "Version": "2012-10-17",
      "Id": "sqspolicy",
      "Statement": [
        {
          "Sid": "First",
          "Effect": "Allow",
          "Principal": "*",
          "Action": [
            "SQS:SendMessage",
            "SQS:ReceiveMessage"
          ],
          "Resource": "${aws_sqs_queue.aws_oivchenko_queue.arn}",
          "Condition": {
            "ArnEquals": {
              "aws:SourceArn": "${aws_sns_topic.aws_oivchenko_topic.arn}"
            }
          }
        }
      ]
    }
    POLICY
}


resource "aws_sqs_queue" "aws_oivchenko_queue" {
  name = "aws-oivchenko-queue"
  message_retention_seconds = 86400
}

resource "aws_sns_topic" "aws_oivchenko_topic" {
  name = "aws-oivchenko-topic"
}
