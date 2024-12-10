from slack_bolt.adapter.aws_lambda import SlackRequestHandler
from slack_bolt import App

# Boltアプリのインスタンスを作成
app = App()


# メンションされたときのイベントハンドラ
@app.event("app_mention")
def handle_app_mention(event, say):
    user = event["user"]
    say(f"Hello, <@{user}>!")


# Lambdaのハンドラを作成
def lambda_handler(event, context):
    slack_handler = SlackRequestHandler(app)
    return slack_handler.handle(event, context)
