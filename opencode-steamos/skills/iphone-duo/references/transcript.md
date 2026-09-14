Your app might run on the iPhone Duo, but that  doesn't mean it's ready. There's a huge difference
between an app that works on the iPhone Duo and  one that feels specifically designed for it. So,
what do you need to do to get your app ready?  That's what I'm breaking down in this video,
including something cool about the hinge  that opens up opportunities for brand new
app ideas. All right, let's start with the big  one. Your app is going to have six brand new
layout configurations to support with the  iPhone Duo, but you don't build six different
UIs for your app. You're going to support the  same size classes you may already be familiar
with with compact and regular. And the iPhone  Duo has various combinations of these. There's
the compact width, regular height, which is the  typical iPhone combination. But there's a new one,
compact compact. When the iPhone Duo is closed  and in landscape, that's going to be a new one
we have to support. And when the Duo is unfolded,  we get that regular regular size class combination
that we're already used to with the iPad.  So, if your app already fully supports iPad,
you're going to be most of the way there. Now,  I want to be clear. I said fully supports iPad.
That means multitasking, resizability, multiple  instances of your app, landscape, split view,
and I'd argue that even though most apps work on  the iPad, fully supporting the iPad is a different
story. So, you're probably going to have some work  to do here because the last thing you want is just
a stretched out version of your iPhone app when  the user unfolds the Duo. So to implement these
changes, you're going to want to check the  environment values for horizontal size class
and vertical size class and then adapt your UI  accordingly. For example, if on a typical iPhone
layout, you have views that are vertically  stacked on top of each other, maybe you flip
that to horizontally stacked when you're in the  regular regular size class configuration. Or you
can use split view to flatten out your navigation  hierarchy if that makes sense for your app or use
the sidebar configuration for your tab view if  it's information dense. So, if you've been hard-
coding view widths in your app, or maybe you  disabled landscape mode because you just didn't
want to deal with that, not anymore. It's time  to fully support that. But on the bright side,
in fully supporting all this, the multitasking,  the split views, the multiple instances of your
app, landscape mode, you're going to end up with  a really good, fully supported iPad app. So,
it's kind of like a two for one deal. The iPhone  Duo Simulator is shipping with Xcode 27.1,
which Apple says will ship in late September  of 2026. So, if you're watching this before,
then you're going to have to wait a little bit  before you can fully test out all these APIs and
see what your app really looks like on the Duo  simulator. Xcode 27.1 also introduces a new AI
agent skill for resizability. So, that should  help adapt your app for the iPhone Duo. And
this is what apps are going to look like that  are not built with iOS 27 SDK or above. Not a
great look. So, older apps that are no longer  updated are really going to stand out on this
device. So hopefully some of your competitors  are doing that, but you you need to build on
the iOS 27 SDK and above and your app will start  looking like this. Start looking like it actually
supports the iPhone Duo. Of course, you may have  to do a little more work to make it look great,
but building for the iOS 27 SDK is going to be a  great start. Now, let's talk about your toolbars
and tab views because they're going to have to  adjust from the horizontal layout to the vertical
layout and back on the fly depending on what  configuration your user has their iPhone Duo in.
And the biggest tip here, which is what I've been  saying for years, for situations just like this,
use the native components, use built-in  navigation stack, use the default tab view,
use the built-in toolbar API. When you use  these, most of the work to support the iPhone
Duo is already done for you. But if you built your  own custom toolbar or your own custom tab view,
you're you're going to have a lot of work ahead  of you. And I just recommend during that work,
just switch to the native components. You're going  to save yourself so much time and headache. And
honestly, with liquid glass, they look great.  But of course, even if you're using the native
components, there's still some small nuances and  customization you can do. For example, if you have
a tab view and a toolbar with a few buttons, those  are going to go on the side along with the status
bar and the live activities. So, if you have a  lot of toolbar buttons, you're going to run out
of room pretty quickly. To handle this, you need  to adopt the new toolbar overflow API that was
introduced in iOS 27. This is where the toolbar or  tab view options will collapse into a menu button,
and you can adjust which should collapse first.  Maybe your toolbar buttons are more important
than your tab view and you want the tab view to  collapse first. Well, you can configure that with
the toolbar vertical compression behavior API. You  can also give individual toolbar items their own
priority if there's certain buttons you don't want  to go into the overflow menu. And you can set this
with the visibility priority API. Another nuance  to consider with the vertical toolbars is that the
order matters top to bottom. That means you want  the primary action to be up top, any prominent
actions to be right below, and any secondary  ones below that. For example, when you're in
a navigation stack, the back button is the top  button and then the prominent action is right
below. And if you have texton buttons in your  toolbar, those are going to stay up top in the
horizontal toolbar because they're wide. There's  not enough room in the vertical toolbar. So, Apple
recommends a couple of ways to deal with this.  The first is to try and avoid texton buttons when
you can and use Swift UI labels which allow you to  give a text and an icon. That way, the system has
the flexibility to determine where it should go.  For example, by default, icon only buttons will
go in the vertical toolbar and the texton buttons  will go in the horizontal toolbar. But even when
an icon button goes into the overflow menu, well,  that menu will now show the icon and the text. So,
when you use a Swift UI label, you're giving the  system what it needs to properly show your action
no matter the context. But if you absolutely  need a texton button, it's going to go in the
horizontal toolbar. And if there's any related  buttons, you should keep them next to it. So,
Apple does give you a way to prefer the horizontal  toolbar, even for icon only buttons. And for this,
you can use the access behavior API. Here are  some other things to consider for your toolbar. If
you have an icon with a number next to it, like a  cart or an inbox, consider using the badge API to
clean that up. Don't add additional spacing in the  vertical toolbar with toolbar spacers. And that's
because the vertical screen real estate is already  limited. So, let the system do it. And in special
cases where it makes sense to not use a vertical  toolbar, like the calculator app, you can disable
that behavior with the toolbar vertical behavior  API. And if you've built a custom toolbar and you
want to know when to flip that to the vertical  version of it, you can check the toolbar vertical
edge environment value and adjust accordingly.  Now, let's talk about the hinge. The hinge is what
makes the iPhone Duo special. It's literally the  backbone. And in your code, you can get a highle
status like open, closed, or partially open. And  you can even get continuous data on the actual
angle of the hinge in real time. And this opens  the door for all kinds of app ideas or feature
ideas or fun animations. For example, this video  player app is showing a dynamic reflection of
the content on the bottom part of the screen  based on the hinge angle. Apple demonstrated
a toy app they made where the hinge can act  as a whammy for guitar. You strum the guitar
strings and then move the hinge back and forth  to adjust the pitch bend. Like listen to this.
Not going to lie, that's pretty cool. And  then here's a little code snippet of what
the onhinge change modifier looks like. Now,  of course, that's a fun little toy, but do some
brainstorming. I bet you could come up with some  really cool things to do in your app. And even
though it may sound silly, things like this have  worked before when adapting your UI to the various
poses the iPhone Duo is capable of. There are  certain areas you're going to need to adjust to,
like the fold in the center of the screen or  the inner and outer cameras. These are called
reserved regions and your UI needs to adapt to  them. For example, if something is in the center
of the phone when it's unfolded, it should move  to one side when partially folded. Or view should
adjust their size so they are split evenly when  partially folded. Essentially, you don't want
your content or controls to be obstructed by the  fold. And if you're using native containers like
navigation stack, split view, tab view, list,  scroll view, adjusting to the reserve regions,
that's built right in. However, if you need to  handle this manually, Apple gives us some APIs to
do that. You can access the regions, their frame  dimensions and whether the region is active or not
with geometry reader. And there are two types of  reserved regions. There's dot division which is
the fold and then there's dot occlusion which  are the outer and inner cameras. And these can
either be active, for example, when the fold  is partially folded or inactive when the duo
is fully unfolded. And like I said, the built-in  containers like navigation stack, they handle this
out of the box. But if you do need a custom view  to do it, Apple gave us a new container called
layout container. And a layout container takes in  something called an arrangement to determine how
to handle the fold. An arrangement can either  be a split or an overlay depending on the type
of UI you need. An arrangement takes in inputs and  gives outputs. Examples of inputs can be what size
class configuration we're currently in. What's the  aspect ratio? What are the reserved regions? And
then based on that input, you can declare whether  you want to show a view at all. And if you do want
to show it, you can declare the frame. And Apple  gives us various system arrangements that we can
use in our apps. Here's some example code showing  an arrangement view in the split configuration.
There's also a new safe area to take into account  and that is the horizontal safe area and these
behave just as the normal safe areas we're used  to except it's just on the side now but this is
where the vertical toolbar will go. So you can  have a full bleed background or background image
using the ignore safe area modifier but just  make sure your content and anything scrolling
respects that safe area so it doesn't get  covered up by the vertical toolbar. All right,
here's some quick hitting small stuff to wrap up.  Standby mode is going to be used a lot more as you
can see in some of these examples. And I bet a lot  of you developers out there maybe neglected full
standby mode adoption for your widgets. Well,  now's the time. Fix that. Apple Pencil support
is coming later this year. So, if your app can  take advantage of that, better start research
and pencil kit. Use the concentric rectangle  API to make sure any custom background matches
the asymmetric shape of the front screen. Your  sheets are going to appear differently depending
on the various poses. And then you might want  to think about drag and drop because if you were
building just an iPhone only app and you didn't  fully support the iPad like I talked about with
multitasking side by side, you probably weren't  worried about drag and drop into your iPhone app.
Well, now that your app is going to be able to be  side by side with any other app if it makes sense
for your app, you might want to think about  fully supporting drag and drop because users
are going to be expecting it. And if you want to  dive deeper into all of this, Apple released six
videos all about building for the iPhone Duo and  they've updated their human interface guidelines
with a special section for it. I'll put the links  to those in the description. And if you're trying
to build an amazing app for the iPhone Duo or  just Apple platforms in general, you should check
out Bitrig. It's an AI development environment  specifically focused on building premium Swift
apps for Apple platforms. It's actually built by  the co-creators of Swift UI that were formerly at
Apple. So, it integrates amazingly well with the  first party Apple frameworks and it specializes
in Swift and Swift UI. And it will know about all  these new APIs and best practices for supporting
the iPhone Duo. It can also create and manage  your app store connect listing, set up your inapp
purchases or subscriptions, and even submit to  the app store for you. The team ships updates on
a weekly basis, so the product is constantly  getting better. Check it out at bitrig.com.
